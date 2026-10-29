-- ============================================================
--  Préparation production (revue d'octobre 2026, partie 3)
--  À appliquer après 20261028233000_fix_errand_completed_at.sql.
-- ============================================================

-- ── 1. users : colonnes modifiables par le client ────────────
-- users_update laisse chaque utilisateur modifier sa propre ligne,
-- et le droit UPDATE couvrait toutes les colonnes : un utilisateur
-- pouvait s'attribuer rating = 5 et nombre_courses = 999.
-- Ces colonnes sont calculées par recalculate_rating (SECURITY
-- DEFINER) ; l'app ne modifie que le rôle requester/runner.
REVOKE UPDATE ON public.users FROM authenticated;
GRANT UPDATE (nom, role, photo_url) ON public.users TO authenticated;

-- ── 2. errands : completed_at fixé avant la contrainte ───────
-- restrict_errand_update est identique à celle de
-- 20261028233000_fix_errand_completed_at.sql ; elle est gardée ici
-- car ce fichier reproduit exactement ce qui a été appliqué.
-- Comme completed_at est désormais rempli dans le trigger BEFORE,
-- l'UPDATE du trigger AFTER plus bas devient inutile.
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

    IF (to_jsonb(NEW) - 'status' - 'runner_id' - 'completed_at')
       IS DISTINCT FROM (to_jsonb(OLD) - 'status' - 'runner_id' - 'completed_at') THEN
        RAISE EXCEPTION 'Seuls le statut et le runner d''une course peuvent être modifiés'
            USING ERRCODE = '42501';
    END IF;

    -- runner_id ne change qu'à l'acceptation
    IF NEW.runner_id IS DISTINCT FROM OLD.runner_id
       AND NOT (OLD.status = 'waiting' AND NEW.status = 'accepted') THEN
        RAISE EXCEPTION 'Le runner ne peut être assigné qu''à l''acceptation'
            USING ERRCODE = '42501';
    END IF;

    -- completed_at est fixé côté serveur au passage à done
    IF NEW.status = 'done' AND OLD.status IS DISTINCT FROM 'done' THEN
        NEW.completed_at := now();
    ELSE
        NEW.completed_at := OLD.completed_at;
    END IF;

    RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.restrict_errand_update() FROM PUBLIC, anon, authenticated;

-- L'UPDATE de completed_at dans le trigger AFTER devient redondant :
-- il réécrivait la ligne et relançait tous les triggers d'errands.
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

    -- Course terminée → notifier le Requester
    IF NEW.status = 'done' AND OLD.status IN ('accepted', 'delivering') THEN
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

-- ── 3. Note moyenne : nombre d'avis non plafonné ─────────────
-- La note reste la moyenne des 10 derniers avis, mais
-- nombre_courses comptait les lignes de cette sous-requête
-- (LIMIT 10) et restait bloqué à 10.
CREATE OR REPLACE FUNCTION public.recalculate_rating()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_new_rating  NUMERIC(3,2);
    v_nb_reviews  INTEGER;
BEGIN
    SELECT ROUND(AVG(note)::NUMERIC, 2)
    INTO v_new_rating
    FROM (
        SELECT note
        FROM public.reviews
        WHERE reviewed_user_id = NEW.reviewed_user_id
        ORDER BY created_at DESC
        LIMIT 10
    ) last_reviews;

    SELECT COUNT(*)
    INTO v_nb_reviews
    FROM public.reviews
    WHERE reviewed_user_id = NEW.reviewed_user_id;

    UPDATE public.users
    SET
        rating         = COALESCE(v_new_rating, 0),
        nombre_courses = v_nb_reviews
    WHERE id = NEW.reviewed_user_id;

    RETURN NEW;
END;
$$;
