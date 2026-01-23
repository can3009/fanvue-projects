# Mass Messages Enhancements Plan

## Goal Description
Upgrade the Mass Messages Dialog to be a powerful marketing tool. Key additions include multi-language support for AI generation, granular audience filters, and rich content features like media attachments and PPV pricing.

## Proposed Features

### 1. 🌍 Universal Language Selector
Add a dropdown/toggle to select the target language for Grok-generated messages.
- **Options**: German (Default), English, Spanish, French, Italian.
- **Implementation**: Pass a `language` parameter to the `generate-broadcast` Edge Function. The prompt to the LLM will be adjusted to output in the requested language.

### 2. 🔍 Advanced Filters (Client-Side filtering for MVP)
Refine the audience selection beyond basic lists.
- **Last Active**: "Active in last 24h", "Last 7 days", "Last 30 days".
- **Spend Tier**: "High Spenders (>$100)", "Medium (>$20)", "Low/None".
- *Note*: This requires fetching member details. If the API only gives counts, we might need to fetch the full member list or trust the "Smart Lists" (e.g., "Spent more than $50" is already a smart list).

### 3. 📸 Media & PPV (Vault Integration)
A mass message is often useless without content.
- **Media Picker**: Integration with the Vault (existing images/videos/audio).
- **PPV Price**: If Media is selected, allow setting a price (Unlock Amount).

### 4. ✨ Personalization
- **Placeholders**: Add buttons to insert `{name}` or `{username}` which gets replaced per fan.

### 5. 🚀 High-Speed Scheduling (Turbo-Planung)
- **Calendar View**: A visual monthly calendar where you can drag & drop generated messages.
- **Quick Clone**: "Duplicate to next 4 Fridays" logic.
- **Goal**: Enable planning an entire month of content in under 5 minutes.
- **Implementation**: `scheduled_broadcasts` table + Calendar Widget in Flutter.

### 6. 💾 Templates
- Save successful messages as templates for reuse.

## UI Redesign Ideas
- **Split View**: Left side = Audience Selection (Filters), Right side = Composer (Message, Media, AI Settings).
- **Preview Card**: Show a live preview of how the message looks to a fan.

## Implementation Steps

### Step 1: Language & AI
- Update `BroadcastRepository` and `generate-broadcast` function to accept `language`.
- Add Language Dropdown next to "Mit Grok generieren" button.

### Step 2: Media & Price
- Add `MediaAttachmentWidget` to the dialog (selecting from Vault).
- Add `PriceInputWidget` (only visible if media is attached).

### Step 3: Filters & Scheduling
- Implement filtering logic.
- Add "Send Later" datetime picker (MVP: just UI, backend later).
- Build Calendar View.
