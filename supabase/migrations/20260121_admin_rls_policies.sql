-- Migration: Add RLS policies for admin Flutter app
-- Allows authenticated users to read/write data

-- ============================================
-- CREATORS TABLE
-- ============================================
-- Select: authenticated users can see all creators
CREATE POLICY creators_select_authenticated ON public.creators
    FOR SELECT
    TO authenticated
    USING (true);

-- Insert: authenticated users can create creators
CREATE POLICY creators_insert_authenticated ON public.creators
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Update: authenticated users can update creators
CREATE POLICY creators_update_authenticated ON public.creators
    FOR UPDATE
    TO authenticated
    USING (true);

-- Delete: authenticated users can delete creators
CREATE POLICY creators_delete_authenticated ON public.creators
    FOR DELETE
    TO authenticated
    USING (true);

-- ============================================
-- MESSAGES TABLE
-- ============================================
-- Select: authenticated users can see all messages
CREATE POLICY messages_select_authenticated ON public.messages
    FOR SELECT
    TO authenticated
    USING (true);

-- Insert: authenticated users can create messages
CREATE POLICY messages_insert_authenticated ON public.messages
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- ============================================
-- FANS TABLE
-- ============================================
-- Select: authenticated users can see all fans
CREATE POLICY fans_select_authenticated ON public.fans
    FOR SELECT
    TO authenticated
    USING (true);

-- Insert: authenticated users can create fans
CREATE POLICY fans_insert_authenticated ON public.fans
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Update: authenticated users can update fans
CREATE POLICY fans_update_authenticated ON public.fans
    FOR UPDATE
    TO authenticated
    USING (true);

-- ============================================
-- FAN_PROFILES TABLE
-- ============================================
CREATE POLICY fan_profiles_select_authenticated ON public.fan_profiles
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY fan_profiles_insert_authenticated ON public.fan_profiles
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY fan_profiles_update_authenticated ON public.fan_profiles
    FOR UPDATE
    TO authenticated
    USING (true);

-- ============================================
-- CONVERSATION_STATE TABLE
-- ============================================
CREATE POLICY conversation_state_select_authenticated ON public.conversation_state
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY conversation_state_insert_authenticated ON public.conversation_state
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY conversation_state_update_authenticated ON public.conversation_state
    FOR UPDATE
    TO authenticated
    USING (true);

-- ============================================
-- TRANSACTIONS TABLE
-- ============================================
CREATE POLICY transactions_select_authenticated ON public.transactions
    FOR SELECT
    TO authenticated
    USING (true);

-- ============================================
-- CREATOR_OAUTH_TOKENS TABLE
-- ============================================
CREATE POLICY creator_oauth_tokens_select_authenticated ON public.creator_oauth_tokens
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY creator_oauth_tokens_insert_authenticated ON public.creator_oauth_tokens
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY creator_oauth_tokens_update_authenticated ON public.creator_oauth_tokens
    FOR UPDATE
    TO authenticated
    USING (true);

CREATE POLICY creator_oauth_tokens_delete_authenticated ON public.creator_oauth_tokens
    FOR DELETE
    TO authenticated
    USING (true);

-- ============================================
-- CREATOR_INTEGRATIONS TABLE (if exists)
-- ============================================
DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'creator_integrations') THEN
        EXECUTE 'CREATE POLICY creator_integrations_select_authenticated ON public.creator_integrations FOR SELECT TO authenticated USING (true)';
        EXECUTE 'CREATE POLICY creator_integrations_insert_authenticated ON public.creator_integrations FOR INSERT TO authenticated WITH CHECK (true)';
        EXECUTE 'CREATE POLICY creator_integrations_update_authenticated ON public.creator_integrations FOR UPDATE TO authenticated USING (true)';
        EXECUTE 'CREATE POLICY creator_integrations_delete_authenticated ON public.creator_integrations FOR DELETE TO authenticated USING (true)';
    END IF;
END $$;
