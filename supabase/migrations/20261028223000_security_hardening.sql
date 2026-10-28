-- ============================================================
--  Durcissement sécurité (revue Supabase, octobre 2026)
--  À appliquer après snackrunner_schema.sql et fcm_tokens_migration.sql
-- ============================================================

-- Les sections 1 à 3 sont conditionnelles : la base en ligne ne
-- contient pas tous les objets de fcm_tokens_migration.sql (la vue
-- et la fonction trigger n'y existent pas, et fcm_tokens y a déjà des
-- politiques séparées par commande).

-- ── 1. Vue unread_notifications ──────────────────────────────
-- Une vue s'exécute par défaut avec les droits de son créateur
-- (postgres) et ignore donc la RLS de notifications/errands :
-- n'importe quel client avec la clé anon pouvait lire les
-- notifications de tous les utilisateurs. security_invoker
-- applique la RLS de l'utilisateur qui interroge la vue.
DO $$
BEGIN
    IF to_regclass('public.unread_notifications') IS NOT NULL THEN
        ALTER VIEW public.unread_notifications SET (security_invoker = true);
        REVOKE ALL ON public.unread_notifications FROM anon;
    END IF;
END;
$$;

-- ── 2. Politique fcm_tokens ──────────────────────────────────
-- (select auth.uid()) est évalué une seule fois par requête
-- au lieu d'une fois par ligne.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_policies
               WHERE schemaname = 'public' AND tablename = 'fcm_tokens'
                 AND policyname = 'fcm_tokens_own') THEN
        DROP POLICY "fcm_tokens_own" ON public.fcm_tokens;
        CREATE POLICY "fcm_tokens_own"
            ON public.fcm_tokens FOR ALL
            TO authenticated
            USING      ((select auth.uid()) = user_id)
            WITH CHECK ((select auth.uid()) = user_id);
    END IF;
END;
$$;

-- ── 3. search_path figé sur la fonction trigger ──────────────
DO $$
BEGIN
    IF to_regprocedure('public.update_fcm_token_timestamp()') IS NOT NULL THEN
        ALTER FUNCTION public.update_fcm_token_timestamp() SET search_path = '';
    END IF;
END;
$$;

-- ── 4. Empêcher l'auto-promotion en admin ────────────────────
-- La politique users_update laisse chaque utilisateur modifier sa
-- propre ligne, colonne role comprise : il pouvait passer role = 'admin'
-- et obtenir tous les droits de is_admin().
-- Ce trigger bloque toute attribution du rôle admin par un client
-- (anon / authenticated). Le service role et le SQL editor ne
-- sont pas concernés.
CREATE OR REPLACE FUNCTION public.prevent_admin_self_assign()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
    IF current_user IN ('anon', 'authenticated')
       AND NEW.role = 'admin'
       AND (TG_OP = 'INSERT' OR OLD.role IS DISTINCT FROM 'admin') THEN
        RAISE EXCEPTION 'Attribution du rôle admin interdite'
            USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.prevent_admin_self_assign() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS users_prevent_admin_self_assign ON public.users;
CREATE TRIGGER users_prevent_admin_self_assign
    BEFORE INSERT OR UPDATE OF role ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.prevent_admin_self_assign();
