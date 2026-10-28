// ============================================================
//  notify-new-errand/index.ts
//
//  Déclencheur : Supabase Database Webhook
//    → Table   : public.errands
//    → Event   : INSERT
//    → URL     : https://<project>.supabase.co/functions/v1/notify-new-errand
//
//  Rôle : Envoie une notification push FCM à tous les runners
//  actifs dès qu'une nouvelle course est publiée.
//
//  Flux :
//    1. Reçoit le payload du webhook (nouvelle ligne errands)
//    2. Récupère le profil du requester pour le message
//    3. Sélectionne tous les users avec role = 'runner'
//    4. Pour chaque runner, envoie la notif FCM
//       (en parallèle, avec Promise.allSettled)
//    5. Insère dans public.notifications pour l'historique in-app
// ============================================================

import {
  ok,
  err,
  checkSharedSecret,
  getSupabaseAdmin,
  sendFcmNotification,
  type Errand,
  type User,
} from "../_shared/index.ts";

// ── Types du payload Supabase Webhook ────────────────────────

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  record: Errand;
  old_record: Errand | null;
  schema: string;
}

// ── Handler principal ────────────────────────────────────────

Deno.serve(async (req: Request): Promise<Response> => {
  // Vérifier la méthode
  if (req.method !== "POST") return err("Méthode non autorisée.", 405);

  // Vérifier le secret webhook (obligatoire)
  const denied = checkSharedSecret(req, "WEBHOOK_SECRET", "x-supabase-webhook-secret");
  if (denied) return denied;

  // Parser le body
  let payload: WebhookPayload;
  try {
    payload = await req.json();
  } catch {
    return err("Payload JSON invalide.");
  }

  // On ne traite que les INSERT sur errands
  if (payload.type !== "INSERT" || payload.table !== "errands") {
    return ok({ skipped: true, reason: "Événement ignoré." });
  }

  if (!payload.record?.id) return err("Payload sans identifiant de course.");

  const supabase = getSupabaseAdmin();

  // Relire la course en base plutôt que faire confiance au payload :
  // le texte envoyé aux runners vient ainsi toujours de la base.
  const { data: errand, error: errandError } = await supabase
    .from("errands")
    .select("*")
    .eq("id", payload.record.id)
    .single<Errand>();

  if (errandError || !errand) {
    console.error("Course introuvable:", errandError);
    return err("Course introuvable.", 404);
  }

  // Ignorer les courses qui ne sont pas en attente
  if (errand.status !== "waiting") {
    return ok({ skipped: true, reason: "Course non en attente." });
  }

  // 1. Récupérer le profil du requester
  const { data: requester, error: requesterError } = await supabase
    .from("users")
    .select("id, nom")
    .eq("id", errand.requester_id)
    .single<Pick<User, "id" | "nom">>();

  if (requesterError || !requester) {
    console.error("Requester introuvable:", requesterError);
    return err("Requester introuvable.", 500);
  }

  // 2. Récupérer tous les runners (sauf le requester lui-même)
  const { data: runners, error: runnersError } = await supabase
    .from("users")
    .select("id, nom")
    .eq("role", "runner")
    .neq("id", errand.requester_id);

  if (runnersError) {
    console.error("Erreur récupération runners:", runnersError);
    return err("Impossible de récupérer les runners.", 500);
  }

  if (!runners || runners.length === 0) {
    console.log("Aucun runner disponible — notification ignorée.");
    return ok({ sent: 0 });
  }

  // 3. Construire le message de notification
  const rewardLabel = errand.reward_type === "argent"
    ? `${errand.reward_amount ?? 0} FCFA`
    : errand.reward_description ?? "Nourriture";

  const notifTitle = "🛒 Nouvelle course disponible !";
  const notifBody  = `${errand.titre} — ${errand.lieu} · Récompense : ${rewardLabel}`;

  // 4. Récupérer les tokens FCM de chaque runner
  const runnerIds = runners.map((r) => r.id);

  const { data: fcmTokens, error: fcmError } = await supabase
    .from("fcm_tokens")
    .select("user_id, token")
    .in("user_id", runnerIds);

  if (fcmError) {
    console.error("Erreur récupération tokens FCM:", fcmError);
  }

  // 5. Envoyer les notifs FCM en parallèle
  let sentCount = 0;

  if (fcmTokens && fcmTokens.length > 0) {
    const results = await Promise.allSettled(
      fcmTokens.map(({ token }) =>
        sendFcmNotification({
          token,
          title: notifTitle,
          body:  notifBody,
          data: {
            type:       "nouvelle_course",
            errand_id:  errand.id,
            errand_titre: errand.titre,
          },
        })
      )
    );

    sentCount = results.filter(
      (r) => r.status === "fulfilled" && r.value === true
    ).length;

    console.log(`FCM envoyé à ${sentCount}/${fcmTokens.length} tokens.`);
  }

  // 6. Insérer les notifications in-app pour chaque runner
  if (runnerIds.length > 0) {
    const notifRows = runnerIds.map((userId) => ({
      user_id:  userId,
      errand_id: errand.id,
      type:     "nouvelle_course" as const,
      message:  notifBody,
    }));

    const { error: notifError } = await supabase
      .from("notifications")
      .insert(notifRows);

    if (notifError) {
      console.error("Erreur insertion notifications in-app:", notifError);
    }
  }

  return ok({
    errand_id:    errand.id,
    runners_notified: runners.length,
    fcm_sent:     sentCount,
  });
});
