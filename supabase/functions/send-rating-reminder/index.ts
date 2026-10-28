// ============================================================
//  send-rating-reminder/index.ts
//
//  Déclencheur : Supabase Cron Job (pg_cron)
//    → Fréquence : toutes les 5 minutes
//    → SQL cron  : voir commentaire en bas de fichier
//    → URL       : https://<project>.supabase.co/functions/v1/send-rating-reminder
//
//  Rôle : Envoie les rappels de notation aux utilisateurs
//  qui n'ont pas encore noté 1h après la fin de leur course.
//
//  Flux :
//    1. Sélectionne les notifications "rappel_notation"
//       dont created_at <= NOW() et is_read = false
//    2. Pour chaque notification, vérifie si l'utilisateur
//       a déjà soumis sa review (pour éviter les doublons)
//    3. Envoie le push FCM si le token existe
//    4. Marque la notification comme lue (is_read = true)
//       pour ne pas la retraiter au prochain cycle
// ============================================================

import {
  ok,
  err,
  checkSharedSecret,
  getSupabaseAdmin,
  sendFcmNotification,
  type Notification,
} from "../_shared/index.ts";

// ── Types ────────────────────────────────────────────────────

interface ReminderNotification extends Notification {
  errand: {
    id: string;
    titre: string;
    requester_id: string;
    runner_id: string | null;
  };
}

// ── Handler principal ────────────────────────────────────────

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return err("Méthode non autorisée.", 405);

  // Vérifier le secret cron (obligatoire)
  const denied = checkSharedSecret(req, "CRON_SECRET", "Authorization", "Bearer ");
  if (denied) return denied;

  const supabase = getSupabaseAdmin();
  const now = new Date().toISOString();

  // 1. Récupérer les rappels de notation arrivés à échéance
  //    et pas encore traités (is_read = false)
  const { data: reminders, error: remindersError } = await supabase
    .from("notifications")
    .select(`
      id,
      user_id,
      errand_id,
      type,
      message,
      is_read,
      created_at,
      errand:errands (
        id,
        titre,
        requester_id,
        runner_id
      )
    `)
    .eq("type", "rappel_notation")
    .eq("is_read", false)
    .lte("created_at", now)
    .limit(100); // Traiter par batch de 100 pour éviter les timeouts

  if (remindersError) {
    console.error("Erreur récupération rappels:", remindersError);
    return err("Impossible de récupérer les rappels.", 500);
  }

  if (!reminders || reminders.length === 0) {
    console.log("Aucun rappel de notation à envoyer.");
    return ok({ processed: 0 });
  }

  console.log(`${reminders.length} rappel(s) à traiter.`);

  const processedIds: string[] = [];
  const skippedIds:   string[] = [];
  let   sentCount = 0;

  // 2. Traiter chaque rappel
  for (const reminder of reminders as ReminderNotification[]) {
    if (!reminder.errand || !reminder.errand_id) {
      // Course supprimée — marquer quand même comme lue
      processedIds.push(reminder.id);
      continue;
    }

    // Vérifier si l'utilisateur a déjà noté pour cette course
    const { data: existingReview } = await supabase
      .from("reviews")
      .select("id")
      .eq("errand_id", reminder.errand_id)
      .eq("reviewer_id", reminder.user_id)
      .maybeSingle();

    if (existingReview) {
      // Déjà noté — marquer comme lu sans envoyer le push
      console.log(`User ${reminder.user_id} a déjà noté — rappel ignoré.`);
      skippedIds.push(reminder.id);
      processedIds.push(reminder.id);
      continue;
    }

    // 3. Récupérer les tokens FCM de cet utilisateur (un par appareil)
    const { data: fcmTokenRows } = await supabase
      .from("fcm_tokens")
      .select("token")
      .eq("user_id", reminder.user_id);

    if (fcmTokenRows && fcmTokenRows.length > 0) {
      const results = await Promise.allSettled(
        fcmTokenRows.map(({ token }) =>
          sendFcmNotification({
            token,
            title: "⭐ N'oublie pas de noter !",
            body:  reminder.message,
            data: {
              type:       "rappel_notation",
              errand_id:  reminder.errand_id,
              errand_titre: reminder.errand.titre,
              screen:     `/errands/${reminder.errand_id}/review`,
            },
          })
        )
      );

      sentCount += results.filter(
        (r) => r.status === "fulfilled" && r.value === true
      ).length;
    } else {
      console.log(`Pas de token FCM pour user ${reminder.user_id} — push ignoré.`);
    }

    processedIds.push(reminder.id);
  }

  // 4. Marquer tous les rappels traités comme lus (batch update)
  if (processedIds.length > 0) {
    const { error: updateError } = await supabase
      .from("notifications")
      .update({ is_read: true })
      .in("id", processedIds);

    if (updateError) {
      console.error("Erreur mise à jour is_read:", updateError);
      // Non bloquant — sera retenté au prochain cycle
    }
  }

  const result = {
    processed: processedIds.length,
    fcm_sent:  sentCount,
    skipped:   skippedIds.length,
    timestamp: now,
  };

  console.log("Résultat rappels notation:", result);
  return ok(result);
});

// ============================================================
//  CONFIGURATION DU CRON JOB SUPABASE
//
//  Dans le Dashboard Supabase → Database → Extensions,
//  active pg_cron, puis exécute ce SQL dans l'éditeur :
//
//  SELECT cron.schedule(
//    'send-rating-reminders',
//    '*/5 * * * *',
//    $$
//      SELECT net.http_post(
//        url     := 'https://<project-ref>.supabase.co/functions/v1/send-rating-reminder',
//        headers := jsonb_build_object(
//          'Content-Type',  'application/json',
//          'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
//        ),
//        body    := '{}'::jsonb
//      ) AS request_id;
//    $$
//  );
//
//  Remplace <project-ref> par ton ID de projet Supabase.
//  Stocke le secret dans Vault plutôt qu'en clair dans cron.job :
//    SELECT vault.create_secret('<valeur de CRON_SECRET>', 'cron_secret');
//
//  Pour vérifier que le cron tourne :
//  SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;
// ============================================================
