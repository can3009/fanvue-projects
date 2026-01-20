-- Migration: 20240116000000_initial_schema.sql

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. CREATORS
CREATE TABLE IF NOT EXISTS public.creators (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    settings JSONB DEFAULT '{}'::jsonb,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. CREATOR_OAUTH_TOKENS
CREATE TABLE IF NOT EXISTS public.creator_oauth_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    creator_id UUID REFERENCES public.creators(id) ON DELETE CASCADE,
    access_token TEXT NOT NULL,
    refresh_token TEXT NOT NULL,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT unique_creator_token UNIQUE (creator_id)
);

-- 3. FANS
CREATE TABLE IF NOT EXISTS public.fans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fanvue_fan_id TEXT UNIQUE NOT NULL,
    username TEXT,
    display_name TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 4. FAN_PROFILES
CREATE TABLE IF NOT EXISTS public.fan_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fan_id UUID REFERENCES public.fans(id) ON DELETE CASCADE,
    creator_id UUID REFERENCES public.creators(id) ON DELETE CASCADE,
    summary TEXT,
    tags TEXT[] DEFAULT '{}',
    stats JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT unique_fan_creator_profile UNIQUE (fan_id, creator_id)
);

-- 5. CONVERSATION_STATE
CREATE TABLE IF NOT EXISTS public.conversation_state (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fan_id UUID REFERENCES public.fans(id) ON DELETE CASCADE,
    creator_id UUID REFERENCES public.creators(id) ON DELETE CASCADE,
    sub_state TEXT DEFAULT 'active', -- active, sleep, browsing, etc.
    last_inbound_at TIMESTAMPTZ,
    last_outbound_at TIMESTAMPTZ,
    sleep_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT unique_fan_creator_state UNIQUE (fan_id, creator_id)
);

-- 6. MESSAGES
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    creator_id UUID REFERENCES public.creators(id) ON DELETE CASCADE,
    fan_id UUID REFERENCES public.fans(id) ON DELETE CASCADE,
    direction TEXT NOT NULL CHECK (direction IN ('inbound', 'outbound')),
    content TEXT,
    fanvue_message_id TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 7. TRANSACTIONS
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    creator_id UUID REFERENCES public.creators(id) ON DELETE CASCADE,
    fan_id UUID REFERENCES public.fans(id) ON DELETE CASCADE,
    fanvue_transaction_id TEXT,
    amount DECIMAL(10, 2),
    currency TEXT DEFAULT 'USD',
    type TEXT, -- tip, subscription, ppv
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 8. JOBS_QUEUE
CREATE TABLE IF NOT EXISTS public.jobs_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    creator_id UUID REFERENCES public.creators(id) ON DELETE CASCADE,
    type TEXT NOT NULL, -- reply, broadcast, followup
    payload JSONB DEFAULT '{}'::jsonb,
    status TEXT DEFAULT 'queued', -- queued, processing, completed, failed
    attempts INTEGER DEFAULT 0,
    last_error TEXT,
    run_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_messages_fan_id_created_at ON public.messages(fan_id, created_at);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at);
CREATE INDEX IF NOT EXISTS idx_jobs_status_run_at ON public.jobs_queue(status, run_at);
CREATE INDEX IF NOT EXISTS idx_fans_fanvue_fan_id ON public.fans(fanvue_fan_id);
CREATE INDEX IF NOT EXISTS idx_transactions_fan_id_created_at ON public.transactions(fan_id, created_at);

-- RLS (Row Level Security)
-- Explicitly enable RLS on all tables to deny public access by default.
ALTER TABLE public.creators ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.creator_oauth_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fan_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jobs_queue ENABLE ROW LEVEL SECURITY;

-- We do not add any policies for 'anon' or 'authenticated' roles just yet.
-- This ensures only the 'service_role' (which bypasses RLS) can access these tables.
-- This matches the requirement: "serverseitiger Zugriff über Supabase Service Role (nicht im Frontend)".
