// ============================================================
//  notify-errand-status/index.ts
//
//  Déclencheur : trigger on_notification_created
//    → Table   : public.notifications
//    → Event   : INSERT
//    → URL     : https://<project>.supabase.co/functions/v1/notify-errand-status
//
//  Rôle : Envoie le push FCM correspondant à chaque notification
//  in-app insérée par le trigger handle_errand_status_change.
//
//  Types gérés :
//    - course_acceptee  → push au requester
//    - course_terminee  → push au requester
//    - course_annulee   → push au runner
//    - nouvelle_course  → push aux runners (géré par notify-new-errand)
//    - rappel_notation  → géré par le cron send-rating-reminder
// ============================================================

import {
  ok,
  err,
  checkSharedSecret,
  getSupabaseAdmin,
  sendFcmNotification,
  type Notification,
  type NotificationType,
} from "../_shared/index.ts";

// ── Types ────────────────────────────────────────────────────

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  schema: string;
  record: Notification;
  old_record: null;
}

// Notifications à envoyer immédiatement en push
const IMMEDIATE_TYPES: NotificationType[] = [
  "course_acceptee",
  "course_terminee",
  "course_annulee",
];

const TITLES: Record<string, string> = {
  course_acceptee: "✅ Course acceptée !",
  course_terminee: "🎉 Course livrée !",
  course_annulee:  "❌ Course annulée",
};

// ── Handler principal ────────────────────────────────────────

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return err("Méthode non autorisée.", 405);

  // Vérifier le secret webhook (obligatoire)
  const denied = checkSharedSecret(req, "WEBHOOK_SECRET", "x-supabase-webhook-secret");
  if (denied) return denied;

  let payload: WebhookPayload;
  try {
    payload = await req.json();
  } catch {
    return err("Payload JSON invalide.");
  }

  // On ne traite que les INSERT sur notifications
  if (payload.type !== "INSERT" || payload.table !== "notifications") {
    return ok({ skipped: true });
  }

  if (!payload.record?.id) return err("Payload sans identifiant de notification.");

  const supabase = getSupabaseAdmin();

  // Relire la notification en base plutôt que faire confiance au payload :
  // destinataire et texte viennent ainsi toujours de la base.
  const { data: notif, error: notifError } = await supabase
    .from("notifications")
    .select("id, user_id, errand_id, type, message")
    .eq("id", payload.record.id)
    .single<Pick<Notification, "id" | "user_id" | "errand_id" | "type" | "message">>();

  if (notifError || !notif) {
    console.error("[notify-errand-status] Notification introuvable:", notifError);
    return err("Notification introuvable.", 404);
  }

  // Ignorer les types gérés ailleurs (nouvelle_course, rappel_notation)
  if (!IMMEDIATE_TYPES.includes(notif.type)) {
    return ok({ skipped: true, reason: `Type '${notif.type}' géré ailleurs.` });
  }

  // Récupérer les tokens FCM du destinataire (un par appareil)
  const { data: fcmTokens } = await supabase
    .from("fcm_tokens")
    .select("token")
    .eq("user_id", notif.user_id);

  if (!fcmTokens || fcmTokens.length === 0) {
    console.log(`[notify-errand-status] Pas de token FCM pour user ${notif.user_id}.`);
    return ok({ sent: 0, reason: "Pas de token FCM." });
  }

  const results = await Promise.allSettled(
    fcmTokens.map(({ token }) =>
      sendFcmNotification({
        token,
        title: TITLES[notif.type] ?? "SnackRunner",
        body:  notif.message,
        data: {
          type:      notif.type,
          errand_id: notif.errand_id ?? "",
          screen:    notif.errand_id ? `/suivi/${notif.errand_id}` : "/dashboard",
        },
      })
    )
  );

  const sent = results.filter(
    (r) => r.status === "fulfilled" && r.value === true
  ).length;

  console.log(`[notify-errand-status] type=${notif.type} user=${notif.user_id} sent=${sent}/${fcmTokens.length}`);

  return ok({ sent, type: notif.type, user_id: notif.user_id });
});
