# Fanvue + Supabase + LLM Bot MVP

Multi-creator chatbot system with per-creator Fanvue credentials stored in the database.

## Architecture

- **Database**: PostgreSQL (Supabase) with RLS
- **Functions**: Deno (Supabase Edge Functions)
- **Admin**: Flutter app for onboarding and management

## Edge Functions

| Function | verify_jwt | Purpose |
|----------|------------|---------|
| `fanvue-oauth-start` | ON | Start OAuth flow, store credentials |
| `oauth-callback` | OFF | Handle Fanvue redirect, exchange tokens |
| `fanvue-webhook` | OFF | Receive Fanvue webhooks |
| `fanvue-connection-health` | ON | Check connection status |
| `fanvue-webhook-test` | ON | Test webhook setup |
| `jobs-worker` | OFF | Process job queue |
| `cron-tick` | OFF | Scheduled maintenance |
| `oauth-connect` | OFF | Legacy (deprecated) |

## Setup

### 1. Database
```bash
supabase db push
# or run SQL from supabase/migrations/
```

### 2. Environment Variables (Supabase Secrets)

**Required (Global Infrastructure Only):**
| Key | Description |
|-----|-------------|
| `SUPABASE_URL` | Auto-set by Supabase |
| `SUPABASE_SERVICE_ROLE_KEY` | Auto-set by Supabase |
| `APP_BASE_URL` | Your admin app URL (e.g., `http://localhost:3000`) |

**Optional:**
| Key | Default | Description |
|-----|---------|-------------|
| `FANVUE_AUTHORIZE_URL` | `https://fanvue.com/oauth/authorize` | OAuth endpoint |
| `FANVUE_TOKEN_URL` | `https://fanvue.com/oauth/token` | Token endpoint |
| `LLM_API_KEY` | - | For jobs-worker |
| `LLM_MODEL` | `gpt-4` | For jobs-worker |

> ⚠️ **DO NOT SET**: `FANVUE_CLIENT_ID`, `FANVUE_CLIENT_SECRET`, `FANVUE_WEBHOOK_SECRET`  
> These are stored **per-creator** in `creator_integrations` table via onboarding.

### 3. Deploy Functions
```bash
supabase functions deploy fanvue-oauth-start
supabase functions deploy oauth-callback
supabase functions deploy fanvue-webhook
supabase functions deploy fanvue-connection-health
supabase functions deploy fanvue-webhook-test
supabase functions deploy jobs-worker
supabase functions deploy cron-tick
```

### 4. Flutter Admin Setup
```bash
cd admin_flutter
flutter pub get
flutter run
```

### 5. Onboarding Flow
1. Login to admin app
2. Click "Add Creator"
3. Enter Fanvue credentials (Client ID, Secret, Webhook Secret)
4. Authorize with Fanvue
5. Configure webhook in Fanvue portal:
   ```
   https://<project>.supabase.co/functions/v1/fanvue-webhook?creatorId=<uuid>
   ```

## Security

- Fanvue credentials stored per-creator in `creator_integrations`
- RLS denies all client access to sensitive tables
- Only service role (Edge Functions) can read secrets
- OAuth uses PKCE (code_verifier + code_challenge)
- Webhook signature: `t=<timestamp>,v0=<hmac-sha256>`

## Data Flow

1. **Onboarding**: Flutter → `fanvue-oauth-start` → stores creds in DB → Fanvue OAuth
2. **Webhook**: Fanvue → `fanvue-webhook?creatorId=X` → validates with DB secret → queues job
3. **Reply**: `jobs-worker` → reads token from DB → calls LLM → sends via Fanvue API
