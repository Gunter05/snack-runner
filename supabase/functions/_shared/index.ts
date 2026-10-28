// ============================================================
//  _shared/index.ts
//  Utilitaires communs à toutes les Edge Functions
// ============================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

// ── Types ────────────────────────────────────────────────────

export type UserRole = "requester" | "runner" | "admin";
export type ErrandStatus = "waiting" | "accepted" | "delivering" | "done" | "cancelled";
export type RewardType = "argent" | "nourriture";

export type NotificationType =
  | "nouvelle_course"
  | "course_acceptee"
  | "course_terminee"
  | "course_annulee"
  | "rappel_notation";

export interface User {
  id: string;
  nom: string;
  email: string;
  role: UserRole;
  rating: number;
  nombre_courses: number;
  photo_url: string | null;
  created_at: string;
}

export interface Errand {
  id: string;
  titre: string;
  description: string | null;
  reward_type: RewardType;
  reward_amount: number | null;
  reward_description: string | null;
  status: ErrandStatus;
  requester_id: string;
  runner_id: string | null;
  lieu: string;
  created_at: string;
  completed_at: string | null;
}

export interface Notification {
  id: string;
  user_id: string;
  errand_id: string | null;
  type: NotificationType;
  message: string;
  is_read: boolean;
  created_at: string;
}

export interface FcmPayload {
  token: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

// ── Client Supabase (service role — côté serveur uniquement) ─

export function getSupabaseAdmin() {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("Variables SUPABASE_URL ou SUPABASE_SERVICE_ROLE_KEY manquantes.");
  return createClient(url, key, {
    auth: { persistSession: false },
  });
}

// ── Authentification des appels serveur ─────────────────────
//
//  Les webhooks et le cron passent un secret partagé dans un header.
//  Si le secret n'est pas configuré, on refuse l'appel : sans ça,
//  n'importe qui possédant la clé anon (publique, embarquée dans
//  l'app) pourrait déclencher la fonction.

export function checkSharedSecret(
  req: Request,
  envName: string,
  headerName: string,
  prefix = "",
): Response | null {
  const secret = Deno.env.get(envName);
  if (!secret) {
    console.error(`Secret ${envName} non configuré — appel refusé.`);
    return err("Fonction non configurée.", 500);
  }
  const received = req.headers.get(headerName) ?? "";
  if (!timingSafeEqual(received, `${prefix}${secret}`)) {
    return err("Non autorisé.", 401);
  }
  return null;
}

function timingSafeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const ab = enc.encode(a);
  const bb = enc.encode(b);
  let diff = ab.length ^ bb.length;
  for (let i = 0; i < bb.length; i++) diff |= (ab[i] ?? 0) ^ bb[i];
  return diff === 0;
}

// ── Réponses HTTP ────────────────────────────────────────────

export function ok(data: unknown = { success: true }): Response {
  return new Response(JSON.stringify(data), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}

export function err(message: string, status = 400): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// ── Envoi FCM via HTTP v1 API ────────────────────────────────
//
//  Supabase Edge Functions tournent sur Deno Deploy.
//  On utilise l'API Firebase Cloud Messaging HTTP v1.
//  Le token de service account est stocké dans les secrets
//  Supabase sous la clé FCM_SERVICE_ACCOUNT_JSON.
//
//  Pour obtenir ce JSON :
//  Firebase Console → Paramètres projet → Comptes de service
//  → Générer une nouvelle clé privée

export async function sendFcmNotification(payload: FcmPayload): Promise<boolean> {
  const projectId = Deno.env.get("FCM_PROJECT_ID");
  const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");

  if (!projectId || !serviceAccountJson) {
    console.warn("FCM non configuré — notification ignorée.");
    return false;
  }

  try {
    // 1. Obtenir un access token OAuth2 depuis le service account
    const accessToken = await getFcmAccessToken(serviceAccountJson);

    // 2. Envoyer le message via FCM HTTP v1
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    const body = {
      message: {
        token: payload.token,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: payload.data ?? {},
        android: {
          priority: "high",
          notification: { sound: "default", channel_id: "snackrunner_default" },
        },
        apns: {
          payload: { aps: { sound: "default", badge: 1 } },
        },
      },
    };

    const res = await fetch(fcmUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const text = await res.text();
      console.error("Erreur FCM:", text);
      return false;
    }

    return true;
  } catch (e) {
    console.error("sendFcmNotification exception:", e);
    return false;
  }
}

// ── Helper : Encodage Base64URL (requis pour JWT) ────────────

function toBase64Url(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  const base64 = btoa(String.fromCharCode(...bytes));
  return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// ── Helper : OAuth2 token depuis service account JSON ────────
//  Implémentation manuelle de l'échange JWT → access_token
//  (Deno n'a pas de SDK Google officiel intégré)

async function getFcmAccessToken(serviceAccountJson: string): Promise<string> {
  const sa = JSON.parse(serviceAccountJson);

  const header = toBase64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const now = Math.floor(Date.now() / 1000);

  const claimSet = toBase64Url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));

  const unsigned = `${header}.${claimSet}`;

  // Importer la clé privée RSA depuis le service account
  // On s'assure de bien gérer les retours à la ligne
  const pem = sa.private_key.replace(/\\n/g, "\n");
  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(pem),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    new TextEncoder().encode(unsigned),
  );

  const jwt = `${unsigned}.${toBase64Url(new Uint8Array(signature))}`;

  // Échanger le JWT contre un access token
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const tokenData = await tokenRes.json();
  if (!tokenData.access_token) {
    console.error("Token exchange failed:", tokenData);
    throw new Error("Impossible d'obtenir l'access token FCM.");
  }
  return tokenData.access_token;
}

function pemToDer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const bin = atob(b64);
  const buf = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
  return buf.buffer;
}
