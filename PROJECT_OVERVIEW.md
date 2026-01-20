# Fanvue Chatbot - Komplette Projektstruktur

## 🎯 Projektziel
Ein Multi-Creator Chatbot-System, das Fanvue-Messages automatisch mit LLM beantwortet. Admins können Creator über eine Flutter-App onboarden und verwalten.

---

## 📁 Projektstruktur

```
fanvue-projects/
├── README.md
├── deno.json
│
├── admin/                          # Legacy HTML Admin (nicht mehr aktiv)
│   └── index.html
│
├── admin_flutter/                  # Flutter Admin App
│   ├── pubspec.yaml
│   └── lib/
│       ├── main.dart               # Entry Point
│       ├── app.dart                # AppRoot mit MaterialApp + Theme
│       │
│       ├── config/
│       │   └── app_config.dart     # Supabase URL/Key Speicherung
│       │
│       ├── theme/
│       │   └── app_theme.dart      # Fanvue Green Dark Theme
│       │
│       ├── data/
│       │   ├── supabase_client_provider.dart
│       │   ├── models/
│       │   │   ├── creator.dart
│       │   │   ├── fan.dart
│       │   │   ├── job.dart
│       │   │   ├── message.dart
│       │   │   ├── dashboard_metrics.dart
│       │   │   └── onboarding_state.dart   # Wizard State Models
│       │   └── repositories/
│       │       ├── auth_repository.dart
│       │       ├── creator_repository.dart
│       │       ├── dashboard_repository.dart
│       │       ├── fans_repository.dart
│       │       ├── jobs_repository.dart
│       │       └── fanvue_connection_repo.dart  # OAuth/Webhook Ops
│       │
│       ├── logic/                  # Riverpod Controllers/Notifiers
│       │   ├── auth_controller.dart
│       │   ├── creators_controller.dart
│       │   ├── dashboard_controller.dart
│       │   ├── fans_controller.dart
│       │   ├── jobs_controller.dart
│       │   └── onboarding_notifier.dart    # Wizard State Management
│       │
│       ├── screens/
│       │   ├── auth_gate.dart      # Auth Check
│       │   ├── config_screen.dart  # Supabase Config
│       │   ├── login_screen.dart   # Login Form
│       │   ├── shell.dart          # Navigation Rail
│       │   ├── dashboard_screen.dart
│       │   ├── creators_screen.dart
│       │   ├── fans_screen.dart
│       │   ├── jobs_screen.dart
│       │   ├── settings_screen.dart
│       │   └── onboarding_screen.dart  # 7-Step Wizard
│       │
│       └── widgets/
│           └── section_card.dart
│
└── supabase/
    ├── config.toml
    │
    ├── migrations/
    │   ├── 20240116000000_initial_schema.sql   # Base Tables
    │   └── 20260118_multi_creator_setup.sql    # Multi-Creator RLS
    │
    └── functions/
        ├── _shared/
        │   ├── supabaseClient.ts
        │   ├── fanvueClient.ts
        │   ├── llmClient.ts
        │   └── types.ts
        │
        ├── fanvue-oauth-start/     # OAuth mit PKCE starten
        │   └── index.ts
        ├── oauth-callback/         # Token Exchange
        │   └── index.ts
        ├── oauth-connect/          # Legacy OAuth (redirect)
        │   └── index.ts
        ├── fanvue-webhook/         # Webhook Handler (Multi-Creator)
        │   └── index.ts
        ├── fanvue-connection-health/  # Health Check
        │   └── index.ts
        ├── fanvue-webhook-test/    # Test Webhook
        │   └── index.ts
        ├── jobs-worker/            # Job Queue Processor
        │   └── index.ts
        └── cron-tick/              # Scheduled Tasks
            └── index.ts
```

---

## 🗃️ Datenbank-Schema (Supabase PostgreSQL)

### Tabellen

```sql
-- CREATORS
CREATE TABLE creators (
    id UUID PRIMARY KEY,           -- = auth.uid() für Multi-Creator
    email TEXT UNIQUE,
    display_name TEXT,
    fanvue_creator_id TEXT UNIQUE,
    settings JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    webhook_secret_vault_key TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- CREATOR OAUTH TOKENS
CREATE TABLE creator_oauth_tokens (
    id UUID PRIMARY KEY,
    creator_id UUID REFERENCES creators(id),
    access_token TEXT NOT NULL,
    refresh_token TEXT NOT NULL,
    expires_at TIMESTAMPTZ,
    scopes TEXT[],
    token_type TEXT DEFAULT 'Bearer',
    UNIQUE(creator_id)
);

-- OAUTH STATES (PKCE Flow)
CREATE TABLE oauth_states (
    state TEXT PRIMARY KEY,
    creator_id UUID REFERENCES creators(id),
    code_verifier TEXT NOT NULL,
    redirect_uri TEXT,
    scopes TEXT[],
    expires_at TIMESTAMPTZ
);

-- CREATOR INTEGRATIONS
CREATE TABLE creator_integrations (
    id UUID PRIMARY KEY,
    creator_id UUID REFERENCES creators(id),
    integration_type TEXT DEFAULT 'fanvue',
    client_id TEXT,
    client_secret_vault_key TEXT,
    webhook_secret_vault_key TEXT,
    redirect_uri TEXT,
    scopes TEXT[],
    is_connected BOOLEAN DEFAULT false,
    last_webhook_at TIMESTAMPTZ,
    last_webhook_error TEXT,
    UNIQUE(creator_id, integration_type)
);

-- FANS
CREATE TABLE fans (
    id UUID PRIMARY KEY,
    creator_id UUID REFERENCES creators(id),
    fanvue_fan_id TEXT,
    username TEXT,
    display_name TEXT,
    UNIQUE(creator_id, fanvue_fan_id)
);

-- MESSAGES
CREATE TABLE messages (
    id UUID PRIMARY KEY,
    creator_id UUID REFERENCES creators(id),
    fan_id UUID REFERENCES fans(id),
    direction TEXT CHECK (direction IN ('inbound', 'outbound')),
    content TEXT,
    fanvue_message_id TEXT,
    created_at TIMESTAMPTZ
);

-- CONVERSATION STATE
CREATE TABLE conversation_state (
    id UUID PRIMARY KEY,
    fan_id UUID REFERENCES fans(id),
    creator_id UUID REFERENCES creators(id),
    sub_state TEXT DEFAULT 'active',
    last_inbound_at TIMESTAMPTZ,
    last_outbound_at TIMESTAMPTZ,
    UNIQUE(fan_id, creator_id)
);

-- JOBS QUEUE
CREATE TABLE jobs_queue (
    id UUID PRIMARY KEY,
    creator_id UUID REFERENCES creators(id),
    fan_id UUID REFERENCES fans(id),
    type TEXT NOT NULL,        -- 'reply', 'broadcast', 'followup'
    payload JSONB DEFAULT '{}',
    status TEXT DEFAULT 'queued',
    attempts INTEGER DEFAULT 0,
    last_error TEXT,
    run_at TIMESTAMPTZ DEFAULT now()
);

-- TRANSACTIONS
CREATE TABLE transactions (
    id UUID PRIMARY KEY,
    creator_id UUID REFERENCES creators(id),
    fan_id UUID REFERENCES fans(id),
    fanvue_transaction_id TEXT,
    amount DECIMAL(10,2),
    type TEXT,                 -- 'tip', 'subscription', 'ppv'
    created_at TIMESTAMPTZ
);
```

### RLS Policies

```sql
-- Creators: Nur eigene Daten
CREATE POLICY creators_select_own ON creators FOR SELECT TO authenticated
    USING (id = auth.uid());
CREATE POLICY creators_insert_own ON creators FOR INSERT TO authenticated
    WITH CHECK (id = auth.uid());
CREATE POLICY creators_update_own ON creators FOR UPDATE TO authenticated
    USING (id = auth.uid());

-- Fans/Messages: Creator sieht eigene
CREATE POLICY fans_select_own ON fans FOR SELECT TO authenticated
    USING (creator_id = auth.uid());
CREATE POLICY messages_select_own ON messages FOR SELECT TO authenticated
    USING (creator_id = auth.uid());

-- OAuth Tokens: Kein Client-Zugriff (nur Service Role)
-- (Keine Policies = nur service_role Zugriff)
```

---

## 🔧 Edge Functions

### 1. fanvue-oauth-start
**Zweck:** OAuth-Flow mit PKCE starten
**Auth:** Erfordert JWT
**Input:**
```json
{
  "client_id": "...",
  "client_secret": "...",
  "scopes": ["read:chat", "write:chat", ...]
}
```
**Output:**
```json
{
  "authorize_url": "https://fanvue.com/oauth/authorize?...",
  "state": "random_state",
  "callback_uri": "https://xxx.supabase.co/functions/v1/oauth-callback"
}
```

### 2. oauth-callback
**Zweck:** Code gegen Tokens tauschen
**Input:** Query params `code`, `state`
**Logic:** 
- State lookup → creator_id
- Token Exchange mit Fanvue
- Tokens in DB speichern
- Redirect zur App

### 3. fanvue-webhook
**Zweck:** Fanvue Events empfangen
**URL:** `https://xxx.supabase.co/functions/v1/fanvue-webhook?creatorId=UUID`
**Events:**
- `message.created` → Fan upsert, Message speichern, Reply-Job erstellen
- `transaction.created` → Transaction speichern, Thank-You Job

### 4. fanvue-connection-health
**Zweck:** Connection Status prüfen
**Output:**
```json
{
  "connected": true,
  "token_present": true,
  "token_expired": false,
  "last_webhook_at": "2026-01-18T...",
  "last_webhook_error": null
}
```

### 5. fanvue-webhook-test
**Zweck:** Test-Webhook senden
**Output:** Test-Ergebnis mit Signatur-Validierung

### 6. jobs-worker
**Zweck:** Jobs aus Queue verarbeiten
**Job Types:** reply, broadcast, followup
**Logic:** LLM aufrufen, Fanvue API Message senden

### 7. cron-tick
**Zweck:** Periodische Tasks (alle 1 Min)
**Tasks:** Expired OAuth States löschen, Pending Jobs triggern

---

## 📱 Flutter App Architektur

### State Management: Riverpod

```dart
// Provider Pattern
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final creatorRepositoryProvider = Provider<CreatorRepository>((ref) {
  return CreatorRepository(ref.watch(supabaseClientProvider));
});

final onboardingNotifierProvider = StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier(ref.watch(fanvueConnectionRepoProvider));
});
```

### Onboarding Wizard Steps

1. **Welcome** - Intro + Voraussetzungen
2. **Creator Profile** - Name, Fanvue ID, isActive
3. **Fanvue Credentials** - Client ID, Secret, Scopes
4. **OAuth Connect** - Authorize URL öffnen
5. **Webhook Setup** - URL + Secret kopieren
6. **Test Connection** - Health Check + Test Webhook
7. **Done** - Erfolgsbestätigung

### Theme (Fanvue Green)

```dart
const fanvueGreen = Color(0xFF00F0C0);
const fanvueDarkBg = Color(0xFF0F0F0F);
const fanvueSurface = Color(0xFF1A1A1A);
```

---

## 🔐 Security Model

| Daten | Speicherort | Zugriff |
|-------|-------------|---------|
| client_secret | Environment / Vault | Service Role |
| webhook_secret | Environment / Vault | Service Role |
| access_token | creator_oauth_tokens | Service Role |
| Creator Profile | creators | RLS: auth.uid() = id |

---

## 📋 Environment Variables (Supabase Secrets)

```
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...
SUPABASE_ANON_KEY=eyJ...
FANVUE_CLIENT_ID=...
FANVUE_CLIENT_SECRET=...
FANVUE_WEBHOOK_SECRET=...
FANVUE_REDIRECT_URI=https://xxx.supabase.co/functions/v1/oauth-callback
LLM_BASE_URL=https://api.openai.com/v1
LLM_API_KEY=sk-...
LLM_MODEL=gpt-4
APP_BASE_URL=http://localhost:3000
```

---

## 🚀 Deployment Commands

```bash
# Migrations
supabase db reset

# Edge Functions
supabase functions deploy fanvue-oauth-start
supabase functions deploy oauth-callback
supabase functions deploy fanvue-webhook
supabase functions deploy fanvue-connection-health
supabase functions deploy fanvue-webhook-test
supabase functions deploy jobs-worker
supabase functions deploy cron-tick

# Flutter
cd admin_flutter
flutter pub get
flutter run
```

---

## 🔄 Datenfluss

1. **Creator Onboarding**
   - App → `fanvue-oauth-start` → Fanvue OAuth → `oauth-callback` → Tokens in DB

2. **Message Flow**
   - Fanvue → `fanvue-webhook?creatorId=X` → Fan + Message in DB → Job in Queue
   - `jobs-worker` → LLM → Fanvue API → Message gesendet

3. **Admin Viewing**
   - App → Supabase RLS → Nur eigene Creator-Daten sichtbar
