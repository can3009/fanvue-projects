-- ============================================
-- HUMAN-LIKE BEHAVIOR MIGRATION (SIMPLIFIED)
-- ============================================

-- 1. FANS TABLE: Add tracking columns
ALTER TABLE public.fans
ADD COLUMN IF NOT EXISTS stage TEXT DEFAULT 'new';

ALTER TABLE public.fans
ADD COLUMN IF NOT EXISTS msg_count_inbound INT DEFAULT 0;

ALTER TABLE public.fans
ADD COLUMN IF NOT EXISTS total_spend DECIMAL(10,2) DEFAULT 0.00;

-- 2. JOBS_QUEUE TABLE: Add debounce columns
ALTER TABLE public.jobs_queue
ADD COLUMN IF NOT EXISTS run_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.jobs_queue
ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.jobs_queue
ADD COLUMN IF NOT EXISTS pending_count INT DEFAULT 0;

-- 3. CRITICAL: Unique index to ensure only ONE queued reply job per fan
-- This enforces the "bundle multiple messages into one response" logic
CREATE UNIQUE INDEX IF NOT EXISTS uq_jobs_one_open_reply
ON public.jobs_queue (creator_id, fan_id, job_type)
WHERE status = 'queued' AND job_type = 'reply';

-- 4. Index for efficient job fetching
CREATE INDEX IF NOT EXISTS idx_jobs_queue_run_at_status
ON public.jobs_queue (run_at, status)
WHERE status = 'queued';

-- 5. Index for stage-based queries
CREATE INDEX IF NOT EXISTS idx_fans_stage
ON public.fans (creator_id, stage);

-- 6. MESSAGES TABLE: Ensure has_media column exists
ALTER TABLE public.messages
ADD COLUMN IF NOT EXISTS has_media BOOLEAN DEFAULT false;

COMMENT ON COLUMN public.jobs_queue.pending_count IS 'Number of messages bundled into this job (for realistic delay calculation)';
COMMENT ON COLUMN public.jobs_queue.last_message_at IS 'Timestamp of the last message that updated this job';
COMMENT ON COLUMN public.fans.stage IS 'Conversation funnel: new -> warmup -> flirty -> sales -> post_purchase -> vip';
