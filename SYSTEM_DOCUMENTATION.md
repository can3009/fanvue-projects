# Fanvue Chatbot System - Komplette Dokumentation

## 🎯 Was ist das Projekt?

Ein **automatisierter Chatbot für Fanvue-Creator**. Das System:
1. Empfängt Nachrichten von Fans über Fanvue-Webhooks
2. Generiert automatische Antworten mit LLM (GPT-4)
3. Sendet die Antworten zurück an Fanvue
4. Unterstützt **mehrere Creator** gleichzeitig (Multi-Tenant)

---

## 🏗️ Tech Stack

| Komponente | Technologie | Zweck |
|------------|-------------|-------|
| **Frontend** | Flutter (Dart) | Admin-App für Creator-Verwaltung |
| **Backend** | Supabase Edge Functions (Deno/TypeScript) | Serverless API |
| **Datenbank** | PostgreSQL (Supabase) | Datenspeicherung mit RLS |
| **LLM** | OpenAI GPT-4 (oder kompatibel) | Antwort-Generierung |
| **Auth** | Supabase Auth | Login für Admins |

---

## 📱 Flutter Admin App

### Was kann die App?

1. **Login** - Admin authentifiziert sich
2. **Dashboard** - Übersicht über Creator, Jobs, Messages
3. **Creator verwalten** - Creator anlegen, bearbeiten, aktivieren/deaktivieren
4. **Onboarding Wizard** - Neuen Creator mit Fanvue verbinden (7 Schritte)
5. **Fans ansehen** - Alle Fans eines Creators
6. **Jobs ansehen** - Warteschlange der zu verarbeitenden Nachrichten

### Onboarding Wizard (7 Schritte)

**Schritt 1: Welcome**
- Erklärt was benötigt wird (Fanvue Developer Account)
- Zeigt Voraussetzungen

**Schritt 2: Creator Profil**
- Display Name eingeben
- Fanvue Creator ID (optional)
- Aktiv/Inaktiv Toggle

**Schritt 3: Fanvue Credentials**
- User muss in Fanvue Developer Portal eine App erstellen
- Client ID eingeben
- Client Secret eingeben (wird NUR an Server gesendet, nicht gespeichert)
- Redirect URL wird angezeigt (muss in Fanvue eingetragen werden)
- Scopes werden angezeigt (alle müssen in Fanvue aktiviert sein)

**Schritt 4: OAuth Connect**
- Button "Connect Fanvue" öffnet Fanvue Authorization
- User loggt sich bei Fanvue ein
- User genehmigt Permissions
- Fanvue redirected zurück zu unserem Server
- Server speichert Access Token + Refresh Token

**Schritt 5: Webhook Setup**
- Webhook URL wird angezeigt (enthält creatorId als Query Parameter)
- Webhook Secret wird generiert (einmalig angezeigt!)
- User muss beides in Fanvue Webhook-Einstellungen eintragen
- "Message Received" Event aktivieren

**Schritt 6: Test Connection**
- Health Check zeigt:
  - Token vorhanden? ✅/❌
  - Token abgelaufen? ✅/❌
  - Letzter Webhook? Datum oder "Nie"
  - Letzte Fehler?
- Button "Send Test Webhook" testet die Verbindung

**Schritt 7: Done**
- Erfolgsmeldung
- Button "Go to Dashboard"

---

## 🔄 Der komplette Message-Flow

### 1. Fan schreibt Nachricht auf Fanvue

```
Fan → Fanvue Platform → Webhook an unseren Server
```

### 2. Webhook wird empfangen

```
POST /fanvue-webhook?creatorId=abc-123
Headers: x-fanvue-signature: sha256=xxxx
Body: {
  "event": "message.created",
  "data": {
    "senderId": "fan_456",
    "senderUsername": "CoolFan123",
    "content": "Hey, was machst du heute?",
    "id": "msg_789"
  }
}
```

### 3. Server verarbeitet Webhook

```typescript
// 1. CreatorId aus URL extrahieren
const creatorId = url.searchParams.get("creatorId");

// 2. Webhook Secret für diesen Creator laden
const webhookSecret = getSecretFromVault(creatorId);

// 3. Signatur prüfen
const isValid = verifyHMAC(rawBody, webhookSecret, signatureHeader);
if (!isValid) return 401 Invalid Signature;

// 4. Fan in DB anlegen/aktualisieren
const fan = await supabase.from("fans").upsert({
  creator_id: creatorId,
  fanvue_fan_id: "fan_456",
  username: "CoolFan123"
});

// 5. Nachricht speichern
await supabase.from("messages").insert({
  creator_id: creatorId,
  fan_id: fan.id,
  direction: "inbound",
  content: "Hey, was machst du heute?"
});

// 6. Reply-Job in Warteschlange
await supabase.from("jobs_queue").insert({
  creator_id: creatorId,
  fan_id: fan.id,
  type: "reply",
  payload: { fan_message: "Hey, was machst du heute?" }
});
```

### 4. Jobs-Worker verarbeitet Job

Der `jobs-worker` wird periodisch aufgerufen (cron) oder nach Webhook getriggert:

```typescript
// 1. Nächsten Job holen
const job = await supabase.from("jobs_queue")
  .select("*")
  .eq("status", "queued")
  .order("run_at")
  .limit(1)
  .single();

// 2. Creator-Settings laden (Persona, Stil)
const creator = await supabase.from("creators")
  .select("settings")
  .eq("id", job.creator_id)
  .single();

// 3. Letzte Nachrichten laden (Kontext)
const history = await supabase.from("messages")
  .select("*")
  .eq("fan_id", job.fan_id)
  .order("created_at", { ascending: false })
  .limit(10);

// 4. LLM aufrufen
const prompt = buildPrompt(creator.settings.persona, history, job.payload.fan_message);
const response = await callOpenAI(prompt);

// 5. Antwort über Fanvue API senden
const accessToken = await getAccessToken(job.creator_id);
await fetch("https://api.fanvue.com/messages", {
  method: "POST",
  headers: { Authorization: `Bearer ${accessToken}` },
  body: JSON.stringify({
    recipientId: job.payload.fanvue_fan_id,
    content: response.text
  })
});

// 6. Outbound-Nachricht speichern
await supabase.from("messages").insert({
  creator_id: job.creator_id,
  fan_id: job.fan_id,
  direction: "outbound",
  content: response.text
});

// 7. Job als erledigt markieren
await supabase.from("jobs_queue")
  .update({ status: "completed" })
  .eq("id", job.id);
```

### 5. Fan erhält Antwort

```
Server → Fanvue API → Fanvue Platform → Fan
```

---

## 🔐 Sicherheitskonzept

### Multi-Creator Isolation

Jeder Creator hat:
- Eigene `creator_id` (= auth.uid() des Admin-Users)
- Eigene Webhook-URL: `/fanvue-webhook?creatorId=abc-123`
- Eigene OAuth Tokens
- Eigene Fans + Messages (durch RLS isoliert)

### RLS (Row Level Security)

```sql
-- Fans: Creator sieht nur seine eigenen
CREATE POLICY fans_select_own ON fans
FOR SELECT TO authenticated
USING (creator_id = auth.uid());

-- Messages: Creator sieht nur seine eigenen
CREATE POLICY messages_select_own ON messages
FOR SELECT TO authenticated
USING (creator_id = auth.uid());
```

### Secret Management

| Secret | Wo gespeichert | Wer hat Zugriff |
|--------|----------------|-----------------|
| Client Secret | Supabase Vault / Env | Nur Edge Functions |
| Webhook Secret | Supabase Vault / Env | Nur Edge Functions |
| Access Token | `creator_oauth_tokens` Tabelle | Nur Service Role (keine RLS Policy) |
| Refresh Token | `creator_oauth_tokens` Tabelle | Nur Service Role |

### OAuth Flow (PKCE)

1. App generiert `state` + `code_verifier`
2. App ruft `fanvue-oauth-start` auf
3. Server speichert `state` + `code_verifier` in `oauth_states`
4. Server gibt `authorize_url` zurück
5. User öffnet URL, loggt sich bei Fanvue ein
6. Fanvue redirected zu `oauth-callback?code=xxx&state=yyy`
7. Server prüft `state`, holt `code_verifier`
8. Server tauscht `code` + `code_verifier` gegen Tokens
9. Tokens werden verschlüsselt in DB gespeichert

---

## 📊 Datenbank-Beziehungen

```
┌─────────────┐
│   creators  │
│─────────────│
│ id (PK)     │◄──────────────┐
│ email       │               │
│ display_name│               │
│ settings    │               │
└─────────────┘               │
      │                       │
      │ 1:1                   │
      ▼                       │
┌─────────────────────┐       │
│ creator_oauth_tokens│       │
│─────────────────────│       │
│ creator_id (FK)     │       │
│ access_token        │       │
│ refresh_token       │       │
│ expires_at          │       │
└─────────────────────┘       │
                              │
      ┌───────────────────────┤
      │                       │
      ▼                       │
┌─────────────┐         ┌─────────────┐
│    fans     │         │  messages   │
│─────────────│         │─────────────│
│ id (PK)     │◄────────│ fan_id (FK) │
│ creator_id  │         │ creator_id  │
│ fanvue_fan_id        │ direction   │
│ username    │         │ content     │
└─────────────┘         └─────────────┘
      │
      │ 1:N
      ▼
┌─────────────────────┐
│ conversation_state  │
│─────────────────────│
│ fan_id (FK)         │
│ creator_id (FK)     │
│ sub_state           │
│ last_inbound_at     │
└─────────────────────┘

┌─────────────┐
│ jobs_queue  │
│─────────────│
│ creator_id  │
│ fan_id      │
│ type        │ (reply, broadcast, followup)
│ payload     │
│ status      │ (queued, processing, completed, failed)
└─────────────┘
```

---

## 🚀 Deployment-Schritte

### 1. Supabase Projekt erstellen
- Dashboard öffnen
- Neues Projekt erstellen
- URL + Anon Key + Service Role Key notieren

### 2. Datenbank-Migration ausführen
```bash
supabase db reset
# ODER: SQL manuell im Dashboard ausführen
```

### 3. Environment Variables setzen
In Supabase Dashboard → Edge Functions → Secrets:
```
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...
FANVUE_CLIENT_ID=...
FANVUE_CLIENT_SECRET=...
FANVUE_WEBHOOK_SECRET=...
LLM_BASE_URL=https://api.openai.com/v1
LLM_API_KEY=sk-...
LLM_MODEL=gpt-4
```

### 4. Edge Functions deployen
```bash
supabase functions deploy fanvue-oauth-start
supabase functions deploy oauth-callback
supabase functions deploy fanvue-webhook
supabase functions deploy fanvue-connection-health
supabase functions deploy fanvue-webhook-test
supabase functions deploy jobs-worker
supabase functions deploy cron-tick
```

### 5. Cron Job einrichten
Im Dashboard pg_cron aktivieren:
```sql
SELECT cron.schedule('process-jobs', '* * * * *', 
  $$SELECT net.http_post(
    'https://xxx.supabase.co/functions/v1/cron-tick',
    '{}'::jsonb
  )$$
);
```

### 6. Flutter App konfigurieren
```bash
cd admin_flutter
flutter pub get
flutter run
```

### 7. Ersten Creator onboarden
1. App öffnen
2. Supabase URL + Key eingeben
3. Einloggen (oder registrieren)
4. Dashboard → "Add Creator" klicken
5. Wizard durchlaufen

---

## ⚠️ Bekannte Limitierungen

1. **Webhook Secret**: Aktuell ein globales Secret, nicht pro Creator (TODO: Vault Integration)
2. **Token Refresh**: Noch kein automatischer Refresh wenn Token abläuft
3. **Rate Limits**: Keine Rate Limiting für LLM-Calls
4. **Error Recovery**: Jobs werden bei Fehlern nicht automatisch wiederholt
5. **Fanvue API**: Hypothetische Endpoints (echte API-Docs prüfen)

---

## 📝 Verbesserungsvorschläge für ChatGPT

1. **Ist die Architektur skalierbar für 100+ Creator?**
2. **Wie kann man Token-Refresh automatisieren?**
3. **Ist die RLS-Konfiguration sicher genug?**
4. **Wie würde man das System testen (Unit/Integration Tests)?**
5. **Soll der Webhook-Handler idempotent sein (doppelte Messages verhindern)?**
6. **Wie kann man das LLM-Prompting verbessern für personalisierte Antworten?**
