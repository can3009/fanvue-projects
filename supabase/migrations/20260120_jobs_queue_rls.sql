-- Add RLS policies for jobs_queue table
-- creators.id = auth.uid() in this system, so creator_id can be compared directly

-- Select policy: users can see jobs for their creator
CREATE POLICY jobs_select_own ON public.jobs_queue
    FOR SELECT
    TO authenticated
    USING (creator_id = auth.uid());

-- Update policy: users can update jobs for their creator
CREATE POLICY jobs_update_own ON public.jobs_queue
    FOR UPDATE
    TO authenticated
    USING (creator_id = auth.uid());

-- Insert policy: users can insert jobs for their creator
CREATE POLICY jobs_insert_own ON public.jobs_queue
    FOR INSERT
    TO authenticated
    WITH CHECK (creator_id = auth.uid());
