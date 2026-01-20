-- Migration: 20260118_multi_creator_setup.sql
-- Purpose: Enable multi-creator support with secure secret storage

-- ============================================
-- 1. UPDATE CREATORS TABLE
-- ============================================

-- Add new columns to creators table
ALTER TABLE public.creators 
ADD COLUMN IF NOT EXISTS display_name TEXT,
ADD COLUMN IF NOT EXISTS fanvue_creator_id TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS webhook_secret_vault_key TEXT;

-- Note: We keep id as UUID but will set id = auth.uid() on INSERT via app logic
-- This allows existing UUIDs to remain valid while new creators use auth.uid()

-- ============================================
-- 2. CREATE OAUTH_STATES TABLE (for PKCE flow)
-- ============================================

CREATE TABLE IF NOT EXISTS public.oauth_states (
    state TEXT PRIMARY KEY,
    creator_id UUID NOT NULL REFERENCES public.creators(id) ON DELETE CASCADE,
    code_verifier TEXT NOT NULL,
    redirect_uri TEXT,
    scopes TEXT[],
    created_at TIMESTAMPTZ DEFAULT now(),
    -- Auto-expire after 10 minutes
    expires_at TIMESTAMPTZ DEFAULT (now() + interval '10 minutes')
);

-- Index for cleanup
CREATE INDEX IF NOT EXISTS idx_oauth_states_expires_at ON public.oauth_states(expires_at);

-- ============================================
-- 3. UPDATE CREATOR_OAUTH_TOKENS TABLE
-- ============================================

ALTER TABLE public.creator_oauth_tokens
ADD COLUMN IF NOT EXISTS scopes TEXT[],
ADD COLUMN IF NOT EXISTS token_type TEXT DEFAULT 'Bearer',
ADD COLUMN IF NOT EXISTS scope TEXT;

-- ============================================
-- 4. UPDATE FANS TABLE - ensure unique constraint
-- ============================================

-- First, add creator_id if missing (for multi-creator support)
ALTER TABLE public.fans
ADD COLUMN IF NOT EXISTS creator_id UUID REFERENCES public.creators(id) ON DELETE CASCADE;

-- Create unique constraint for (creator_id, fanvue_fan_id)
-- Drop old constraint if exists
ALTER TABLE public.fans DROP CONSTRAINT IF EXISTS unique_fan_per_creator;
ALTER TABLE public.fans ADD CONSTRAINT unique_fan_per_creator UNIQUE (creator_id, fanvue_fan_id);

-- ============================================
-- 5. CREATE CREATOR_INTEGRATIONS TABLE (stores encrypted client_id for reference)
-- ============================================

CREATE TABLE IF NOT EXISTS public.creator_integrations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    creator_id UUID NOT NULL REFERENCES public.creators(id) ON DELETE CASCADE,
    integration_type TEXT NOT NULL DEFAULT 'fanvue',
    client_id TEXT, -- Can be stored, not secret
    client_secret_vault_key TEXT, -- Reference to Vault secret
    webhook_secret_vault_key TEXT, -- Reference to Vault secret
    redirect_uri TEXT,
    scopes TEXT[],
    is_connected BOOLEAN DEFAULT false,
    last_webhook_at TIMESTAMPTZ,
    last_webhook_error TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT unique_creator_integration UNIQUE (creator_id, integration_type)
);

-- ============================================
-- 6. RLS POLICIES
-- ============================================

-- Enable RLS
ALTER TABLE public.oauth_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.creator_integrations ENABLE ROW LEVEL SECURITY;

-- CREATORS: Allow authenticated users to manage their own profile
DROP POLICY IF EXISTS creators_select_own ON public.creators;
DROP POLICY IF EXISTS creators_insert_own ON public.creators;
DROP POLICY IF EXISTS creators_update_own ON public.creators;

CREATE POLICY creators_select_own ON public.creators
    FOR SELECT TO authenticated
    USING (id = auth.uid());

CREATE POLICY creators_insert_own ON public.creators
    FOR INSERT TO authenticated
    WITH CHECK (id = auth.uid());

CREATE POLICY creators_update_own ON public.creators
    FOR UPDATE TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- CREATOR_INTEGRATIONS: Same pattern
CREATE POLICY integrations_select_own ON public.creator_integrations
    FOR SELECT TO authenticated
    USING (creator_id = auth.uid());

CREATE POLICY integrations_insert_own ON public.creator_integrations
    FOR INSERT TO authenticated
    WITH CHECK (creator_id = auth.uid());

CREATE POLICY integrations_update_own ON public.creator_integrations
    FOR UPDATE TO authenticated
    USING (creator_id = auth.uid());

-- OAUTH_STATES: Service role only (no authenticated access)
-- Default RLS denies all access, which is what we want

-- CREATOR_OAUTH_TOKENS: Restrict to service role only
-- Remove any existing policies that might expose tokens
DROP POLICY IF EXISTS tokens_select_own ON public.creator_oauth_tokens;
DROP POLICY IF EXISTS tokens_insert_own ON public.creator_oauth_tokens;
DROP POLICY IF EXISTS tokens_update_own ON public.creator_oauth_tokens;

-- FANS: Allow creator to see their own fans
DROP POLICY IF EXISTS fans_select_own ON public.fans;
CREATE POLICY fans_select_own ON public.fans
    FOR SELECT TO authenticated
    USING (creator_id = auth.uid());

-- MESSAGES: Allow creator to see their own messages
DROP POLICY IF EXISTS messages_select_own ON public.messages;
CREATE POLICY messages_select_own ON public.messages
    FOR SELECT TO authenticated
    USING (creator_id = auth.uid());

-- ============================================
-- 7. HELPER FUNCTIONS
-- ============================================

-- Function to clean up expired oauth states
CREATE OR REPLACE FUNCTION cleanup_expired_oauth_states()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM public.oauth_states WHERE expires_at < now();
END;
$$;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add trigger to creator_integrations
DROP TRIGGER IF EXISTS update_creator_integrations_updated_at ON public.creator_integrations;
CREATE TRIGGER update_creator_integrations_updated_at
    BEFORE UPDATE ON public.creator_integrations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 8. VAULT SETUP (requires Supabase Vault extension)
-- ============================================

-- Enable vault extension if not exists
-- Note: This may require superuser/dashboard action
-- CREATE EXTENSION IF NOT EXISTS supabase_vault;

-- Vault secrets will be managed via Edge Functions using:
-- supabase.vault.create_secret('fanvue_client_secret_{creatorId}', '{secret}')
-- supabase.vault.read_secret('fanvue_client_secret_{creatorId}')
