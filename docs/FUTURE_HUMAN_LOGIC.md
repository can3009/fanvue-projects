# Future Plan: Human-Like Behavior & Conversation Strategy

This document outlines the architecture for making the bot indistinguishable from a human operator by implementing realistic timing, anti-spam measures, and strategic conversation stages.

## 1. Realistic Delays & Queuing (The "Human Rhythm")

**Goal:** Prevent instant "bot-like" replies. Messages should appear with a natural delay that mimics typing and thinking time.

### Database Changes
- **`jobs_queue`**: Add `run_at` (TIMESTAMP WITH TIME ZONE, default: NOW()).
- **`fans`**: Add `pacing_config` (JSONB) to store individual rhythm:
  ```json
  {
    "base_delay": 45,       // Average seconds to wait (e.g., 30-80s)
    "variance": 15,         // Random +/- deviation
    "long_pause_chance": 0.1 // 10% chance of a 5-minute break
  }
  ```

### Logic Changes
1.  **Webhook (`fanvue-webhook`)**:
    - Calculate `delay_seconds`: `(base +/- random) + (is_long_pause ? 300 : 0)`.
    - Insert Job with `run_at = NOW() + delay_seconds`.
2.  **Worker (`jobs-worker`)**:
    - Update fetch query: `.lte("run_at", new Date().toISOString())`.
    - Only processes jobs that have "matured".

---

## 2. Anti-Spam & Debouncing (The "Active Listener")

**Goal:** If a user sends 3 messages in quick succession ("Hi", "Are you there?", "???"), the bot should NOT send 3 separate replies. It should wait and answer all of them in one go.

### Logic Changes
1.  **Webhook (`fanvue-webhook`)**:
    - Before inserting a new job, check if a job with `status: 'queued'` and `job_type: 'reply'` already exists for this `fan_id`.
    - **If exists:**
        - **Update** the existing job:
            - Update `payload.last_message_id`.
            - *Optional:* Push `run_at` back slightly (e.g., +10s) to wait for the user to finish typing.
    - **If new:** Insert normally.

---

## 3. Conversation State Machine (The "Sales Funnel")

**Goal:** Drive the conversation toward specific goals (Warmup -> Relationship -> Sale) based on history, rather than a generic "one-prompt-fits-all".

### Database Changes
- **`fans` (or new `fan_states`)**: Add columns:
    - `stage` (ENUM: 'new', 'warmup', 'flirty', 'sales', 'post_purchase').
    - `msg_count_inbound` (INT).
    - `total_spend` (DECIMAL).
    - `tags` (JSONB array e.g. ["likes_feet", "hates_smalltalk"]).

### State Start Definitions
1.  **New:** `< 5` messages, no purchases.
2.  **Known/Warmup:** `5-20` messages, active interactions.
3.  **Sales Ready:** High engagement score or specific triggers (e.g., user asks for content).
4.  **VIP:** `>$100` spend (if transaction tracking is enabled).

### Worker Integration
- Fetch `fan` record with `stage` before calling LLM.
- **Dynamic System Prompt:** Inject the stage instructions into the prompt.
    - *New:* "Focus on building trust, ask open questions."
    - *Sales:* "Tease content, offer a bundle, be persuasive."

---

## 4. Response Realism (The "Imperfections")

**Goal:** Bots use perfect grammar and consistent length. Humans don't.

### Implementation (LLM Client)
- **Randomized Style Constraints:** Before calling the LLM, pick a "vibe" for this specific reply:
    - *Short & Snappy:* "Ok cool", "Haha yes" (Low punctuation).
    - *Long & Deep:* Detailed storytelling.
    - *Emoji Heavy:* 😊✨💕 (vs. clean text).
- **Instructions:** "Include 1 grammatical imperfection" or "Use lowercase start" randomly.

---

## Execution Checklist

### Phase 1: Database & Queuing (Foundation)
- [ ] Migration: Add `run_at` to `jobs_queue`.
- [ ] Migration: Add `pacing_config` and `stage` cols to `fans`.
- [ ] Update `jobs-worker` fetch query to respect `run_at`.

### Phase 2: Webhook Intelligence (Control)
- [ ] Implement Delay Calculator in Webhook.
- [ ] Implement "Upsert/Debounce" logic for Jobs (prevent duplicate queueing).

### Phase 3: Brain Upgrade (Context)
- [ ] Update `llmClient.ts` to accept `stage` and `pacing` params.
- [ ] Create specialized System Prompts for each stage (New, Warmup, Sales).
