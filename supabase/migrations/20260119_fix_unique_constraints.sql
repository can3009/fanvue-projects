-- Fix Script: Ensure UNIQUE constraints exist
-- Run this BEFORE the main migration if you have existing data

-- ============================================
-- 1. FIX: creator_oauth_tokens UNIQUE(creator_id)
-- ============================================

-- First, keep only the newest token per creator_id (if duplicates exist)
DELETE FROM public.creator_oauth_tokens t1
WHERE EXISTS (
    SELECT 1 FROM public.creator_oauth_tokens t2
    WHERE t2.creator_id = t1.creator_id
    AND t2.updated_at > t1.updated_at
);

-- Now add UNIQUE constraint
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

-- ============================================
-- 2. FIX: creator_integrations UNIQUE(creator_id, integration_type)
-- ============================================

-- Remove duplicates keeping newest
DELETE FROM public.creator_integrations i1
WHERE EXISTS (
    SELECT 1 FROM public.creator_integrations i2
    WHERE i2.creator_id = i1.creator_id
    AND i2.integration_type = i1.integration_type
    AND i2.updated_at > i1.updated_at
);

-- Add UNIQUE constraint
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

-- ============================================
-- 3. FIX: fans UNIQUE(creator_id, fanvue_fan_id)
-- ============================================

-- Remove duplicates keeping newest
DELETE FROM public.fans f1
WHERE EXISTS (
    SELECT 1 FROM public.fans f2
    WHERE f2.creator_id = f1.creator_id
    AND f2.fanvue_fan_id = f1.fanvue_fan_id
    AND f2.id > f1.id
);

-- Add UNIQUE constraint
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
-- 4. Verify oauth_states has state as PRIMARY KEY or UNIQUE
-- ============================================

-- oauth_states already has state as PRIMARY KEY from initial migration
-- No action needed

-- ============================================
-- 5. Verify Results
-- ============================================

SELECT 
    tc.table_name, 
    tc.constraint_name, 
    tc.constraint_type
FROM information_schema.table_constraints tc
WHERE tc.table_schema = 'public'
AND tc.constraint_type IN ('UNIQUE', 'PRIMARY KEY')
AND tc.table_name IN ('creator_oauth_tokens', 'creator_integrations', 'fans', 'oauth_states')
ORDER BY tc.table_name;
