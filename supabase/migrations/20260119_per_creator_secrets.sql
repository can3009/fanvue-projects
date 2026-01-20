-- Migration: 20260119_per_creator_secrets.sql
-- Purpose: Store per-creator Fanvue credentials directly in DB (no global secrets)
-- Note: All secrets are protected by RLS (service role only) + future Vault migration

-- ============================================
-- 1. UPDATE CREATOR_INTEGRATIONS - Add direct secret storage
-- ============================================

-- Add columns for storing secrets directly (encrypted at rest by Supabase)
ALTER TABLE public.creator_integrations 
ADD COLUMN IF NOT EXISTS fanvue_client_id TEXT,
ADD COLUMN IF NOT EXISTS fanvue_client_secret TEXT,
ADD COLUMN IF NOT EXISTS fanvue_webhook_secret TEXT;

-- Migrate data if client_id exists in old column
UPDATE public.creator_integrations 
SET fanvue_client_id = client_id 
WHERE fanvue_client_id IS NULL AND client_id IS NOT NULL;

-- ============================================
-- 2. ENSURE UNIQUE CONSTRAINTS EXIST
-- ============================================

-- creator_integrations: UNIQUE(creator_id, integration_type)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'unique_creator_integration'
    ) THEN
        ALTER TABLE public.creator_integrations 
        ADD CONSTRAINT unique_creator_integration UNIQUE (creator_id, integration_type);
    END IF;
END $$;

-- creator_oauth_tokens: UNIQUE(creator_id)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'unique_creator_token'
    ) THEN
        ALTER TABLE public.creator_oauth_tokens 
        ADD CONSTRAINT unique_creator_token UNIQUE (creator_id);
    END IF;
END $$;

-- fans: UNIQUE(creator_id, fanvue_fan_id) 
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'unique_fan_per_creator'
    ) THEN
        ALTER TABLE public.fans 
        ADD CONSTRAINT unique_fan_per_creator UNIQUE (creator_id, fanvue_fan_id);
    END IF;
END $$;

-- ============================================
-- 3. RLS POLICIES - Deny client access to sensitive tables
-- ============================================

-- Drop existing policies that might expose secrets
DROP POLICY IF EXISTS integrations_select_own ON public.creator_integrations;
DROP POLICY IF EXISTS integrations_insert_own ON public.creator_integrations;
DROP POLICY IF EXISTS integrations_update_own ON public.creator_integrations;

-- creator_integrations: NO client access (service role only)
-- By not creating any policies, RLS denies all access to authenticated/anon

-- creator_oauth_tokens: NO client access (service role only)
DROP POLICY IF EXISTS tokens_select_own ON public.creator_oauth_tokens;
DROP POLICY IF EXISTS tokens_insert_own ON public.creator_oauth_tokens;
DROP POLICY IF EXISTS tokens_update_own ON public.creator_oauth_tokens;

-- oauth_states: NO client access (service role only)
DROP POLICY IF EXISTS states_select_own ON public.oauth_states;
DROP POLICY IF EXISTS states_insert_own ON public.oauth_states;

-- ============================================
-- 4. CREATORS TABLE - Ensure RLS policies exist
-- ============================================

-- creators: Authenticated users can manage their own profile
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'creators_select_own' AND tablename = 'creators') THEN
        CREATE POLICY creators_select_own ON public.creators
            FOR SELECT TO authenticated
            USING (id = auth.uid());
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'creators_insert_own' AND tablename = 'creators') THEN
        CREATE POLICY creators_insert_own ON public.creators
            FOR INSERT TO authenticated
            WITH CHECK (id = auth.uid());
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'creators_update_own' AND tablename = 'creators') THEN
        CREATE POLICY creators_update_own ON public.creators
            FOR UPDATE TO authenticated
            USING (id = auth.uid())
            WITH CHECK (id = auth.uid());
    END IF;
END $$;

-- ============================================
-- 5. FANS/MESSAGES - Creator can see their own
-- ============================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'fans_select_own' AND tablename = 'fans') THEN
        CREATE POLICY fans_select_own ON public.fans
            FOR SELECT TO authenticated
            USING (creator_id = auth.uid());
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'messages_select_own' AND tablename = 'messages') THEN
        CREATE POLICY messages_select_own ON public.messages
            FOR SELECT TO authenticated
            USING (creator_id = auth.uid());
    END IF;
END $$;

-- ============================================
-- 6. ENSURE RLS IS ENABLED ON ALL TABLES
-- ============================================

ALTER TABLE public.creators ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.creator_integrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.creator_oauth_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oauth_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 7. CLEANUP EXPIRED OAUTH STATES FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION cleanup_expired_oauth_states()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM public.oauth_states WHERE expires_at < now();
END;
$$;

-- ============================================
-- COMMENTS / TODO
-- ============================================

COMMENT ON COLUMN public.creator_integrations.fanvue_client_secret IS 
    'TODO: Migrate to Supabase Vault when ready. Currently stored encrypted at rest.';

COMMENT ON COLUMN public.creator_integrations.fanvue_webhook_secret IS 
    'TODO: Migrate to Supabase Vault when ready. Currently stored encrypted at rest.';
