-- ============================================================
--  Durcissement sécurité, partie 2 (revue Supabase, octobre 2026)
--  Écrit d'après la base en ligne (projet snackrunner).
--
--  AVANT d'appliquer, créer le secret webhook dans le Vault :
--    SELECT vault.create_secret('<secret aléatoire>', 'webhook_secret');
--  et donner la même valeur à WEBHOOK_SECRET dans les secrets
--  des Edge Functions. Sans secret dans le Vault, les triggers
--  n'appellent plus les fonctions (un WARNING est journalisé).
-- ============================================================

-- ── 1. Webhooks : secret lu dans le Vault ────────────────────
-- Les triggers on_errand_created / on_notification_created
-- envoyaient un secret devinable écrit en clair dans leur
-- définition, vers des fonctions déployées sans vérification JWT.

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;

-- SECURITY DEFINER : le trigger se déclenche avec les droits du
-- client (authenticated), qui n'a pas accès au Vault. La fonction
-- vit dans un schéma non exposé et ne prend aucun paramètre client.
CREATE OR REPLACE FUNCTION private.call_edge_function()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_secret text;
BEGIN
    SELECT decrypted_secret INTO v_secret
    FROM vault.decrypted_secrets
    WHERE name = 'webhook_secret';

    IF v_secret IS NULL THEN
        RAISE WARNING 'webhook_secret absent du Vault : appel à % ignoré', TG_ARGV[0];
        RETURN NEW;
    END IF;

    PERFORM net.http_post(
        url     := TG_ARGV[0],
        body    := jsonb_build_object(
            'old_record', to_jsonb(OLD),
            'record',     to_jsonb(NEW),
            'type',       TG_OP,
            'table',      TG_TABLE_NAME,
            'schema',     TG_TABLE_SCHEMA
        ),
        headers := jsonb_build_object(
            'Content-Type',              'application/json',
            'x-supabase-webhook-secret', v_secret
        ),
        timeout_milliseconds := 5000
    );
    RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION private.call_edge_function() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS on_errand_created ON public.errands;
CREATE TRIGGER on_errand_created
    AFTER INSERT ON public.errands
    FOR EACH ROW
    EXECUTE FUNCTION private.call_edge_function(
        'https://zcxmvexdzqlrpbamofie.supabase.co/functions/v1/notify-new-errand');

DROP TRIGGER IF EXISTS on_notification_created ON public.notifications;
CREATE TRIGGER on_notification_created
    AFTER INSERT ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION private.call_edge_function(
        'https://zcxmvexdzqlrpbamofie.supabase.co/functions/v1/notify-errand-status');

-- ── 2. errands : seules les transitions de statut ────────────
-- Les politiques UPDATE contrôlent le statut et le runner mais pas
-- les autres colonnes : le runner qui accepte une course pouvait
-- changer la récompense, le titre ou le requester_id, et le
-- requester qui annule pouvait réassigner runner_id.
CREATE OR REPLACE FUNCTION public.restrict_errand_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
    IF current_user NOT IN ('anon', 'authenticated') OR extensions.is_admin() THEN
        RETURN NEW;
    END IF;

    IF (to_jsonb(NEW) - 'status' - 'runner_id')
       IS DISTINCT FROM (to_jsonb(OLD) - 'status' - 'runner_id') THEN
        RAISE EXCEPTION 'Seuls le statut et le runner d''une course peuvent être modifiés'
            USING ERRCODE = '42501';
    END IF;

    -- runner_id ne change qu'à l'acceptation
    IF NEW.runner_id IS DISTINCT FROM OLD.runner_id
       AND NOT (OLD.status = 'waiting' AND NEW.status = 'accepted') THEN
        RAISE EXCEPTION 'Le runner ne peut être assigné qu''à l''acceptation'
            USING ERRCODE = '42501';
    END IF;

    RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.restrict_errand_update() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS errands_restrict_update ON public.errands;
CREATE TRIGGER errands_restrict_update
    BEFORE UPDATE ON public.errands
    FOR EACH ROW
    EXECUTE FUNCTION public.restrict_errand_update();

-- ── 3. users : emails masqués ────────────────────────────────
-- users_select vaut true : chaque utilisateur connecté lisait l'email
-- de tous les autres. Les colonnes publiques restent lisibles ;
-- l'email de l'utilisateur courant reste disponible via sa session.
REVOKE SELECT ON public.users FROM authenticated;
GRANT SELECT (id, nom, role, rating, nombre_courses, photo_url, created_at)
    ON public.users TO authenticated;

-- ── 4. anon : aucun accès direct aux tables ──────────────────
-- Toutes les politiques ciblent authenticated ; l'inscription passe
-- par le trigger handle_new_user (SECURITY DEFINER). Retirer les
-- droits d'anon ajoute une barrière si une politique trop large
-- est créée un jour.
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES FROM anon;

-- ── 5. Livraison terminée depuis « delivering » ──────────────
-- Le runner passe la course de delivering à done (politique
-- errands_update_runner), mais le trigger ne gérait que accepted → done :
-- ni horodatage, ni notification, ni rappel de notation.
CREATE OR REPLACE FUNCTION public.handle_errand_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    -- Course acceptée → notifier le Requester
    IF NEW.status = 'accepted' AND OLD.status = 'waiting' THEN
        INSERT INTO public.notifications (user_id, errand_id, type, message)
        VALUES (
            NEW.requester_id,
            NEW.id,
            'course_acceptee',
            'Un runner a accepté votre course : ' || NEW.titre
        );
    END IF;

    -- Course terminée → notifier le Requester + horodater
    IF NEW.status = 'done' AND OLD.status IN ('accepted', 'delivering') THEN
        UPDATE public.errands
        SET completed_at = NOW()
        WHERE id = NEW.id;

        INSERT INTO public.notifications (user_id, errand_id, type, message)
        VALUES (
            NEW.requester_id,
            NEW.id,
            'course_terminee',
            'Votre course a été livrée : ' || NEW.titre
        );

        -- Rappels de notation (1h après → géré par un cron Supabase)
        INSERT INTO public.notifications (user_id, errand_id, type, message, created_at)
        VALUES
            (NEW.requester_id, NEW.id, 'rappel_notation',
             'N''oubliez pas de noter votre runner !', NOW() + INTERVAL '1 hour'),
            (NEW.runner_id,    NEW.id, 'rappel_notation',
             'N''oubliez pas de noter le requester !', NOW() + INTERVAL '1 hour');
    END IF;

    -- Course annulée → notifier le Runner si déjà assigné
    IF NEW.status = 'cancelled' AND NEW.runner_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, errand_id, type, message)
        VALUES (
            NEW.runner_id,
            NEW.id,
            'course_annulee',
            'La course a été annulée : ' || NEW.titre
        );
    END IF;

    RETURN NEW;
END;
$$;

-- Un runner en cours de livraison est aussi occupé
CREATE OR REPLACE FUNCTION public.check_runner_availability()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = 'public'
AS $$
BEGIN
    IF NEW.status = 'accepted' AND NEW.runner_id IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM public.errands
            WHERE runner_id = NEW.runner_id
              AND status    IN ('accepted', 'delivering')
              AND id       != NEW.id
        ) THEN
            RAISE EXCEPTION 'Ce runner a déjà une course en cours.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
