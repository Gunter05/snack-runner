-- ============================================================
--  Correctif de 20261028230000_security_hardening_2.sql
--
--  La contrainte completed_at_only_when_done exige completed_at
--  dès qu'une course passe à done, mais restrict_errand_update
--  interdisait aux clients de modifier cette colonne : un runner ne
--  pouvait plus terminer une course. completed_at est désormais
--  rempli par le trigger lui-même (heure serveur), et ignoré s'il
--  vient du client.
-- ============================================================

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
