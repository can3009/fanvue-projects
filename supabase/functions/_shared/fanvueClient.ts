// supabase/functions/_shared/fanvueClient.ts
/// <reference lib="deno.ns" />

export type FanvueSendResult = { messageUuid?: string; id?: string };

export const sendFanvueMessage = async (
    recipientUserUuid: string, // Fanvue userUuid (Empfänger)
    text: string,
    accessToken: string,
): Promise<FanvueSendResult> => {
    const baseUrl = Deno.env.get("FANVUE_API_BASE_URL") ?? "https://api.fanvue.com";
    const apiVersion = Deno.env.get("FANVUE_API_VERSION") ?? "2025-06-26";

    const url =
        `${baseUrl.replace(/\/$/, "")}/chats/${encodeURIComponent(recipientUserUuid)}/message`;

    const resp = await fetch(url, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${accessToken}`,
            "X-Fanvue-API-Version": apiVersion,
        },
        body: JSON.stringify({ text }),
    });

    const raw = await resp.text();

    if (!resp.ok) {
        throw new Error(`Fanvue sendMessage failed ${resp.status}: ${raw}`);
    }

    try {
        const json = JSON.parse(raw) as any;
        // Fanvue nennt es messageUuid – wir geben zusätzlich id zurück, damit dein Worker stabil bleibt
        return { messageUuid: json.messageUuid, id: json.messageUuid ?? json.id };
    } catch {
        return { id: `fanvue-ok-${Date.now()}` };
    }
};

/**
 * Mark a chat as read (green checkmark in Fanvue UI)
 * This is what happens when the creator "opens" the chat
 *
 * @param userUuid - The fan's Fanvue UUID (sender.uuid from webhook)
 * @param accessToken - Creator's OAuth access token
 */
export const markChatAsRead = async (userUuid: string, accessToken: string): Promise<void> => {
    const url = `https://api.fanvue.com/chats/${encodeURIComponent(userUuid)}`;

    console.log("[markChatAsRead] CALLING:", { userUuid, url });

    const resp = await fetch(url, {
        method: "PATCH",
        headers: {
            "Authorization": `Bearer ${accessToken}`,
            "X-Fanvue-API-Version": "2025-06-26",
            "Content-Type": "application/json",
        },
        body: JSON.stringify({ isRead: true }),
    });

    const text = await resp.text().catch(() => "");
    console.log("[markChatAsRead] RESPONSE:", { userUuid, status: resp.status, text });

    if (!(resp.status === 204 || resp.ok)) {
        throw new Error(`markChatAsRead failed: ${resp.status} ${text}`);
    }
};

// ============================================================
// SMART LISTS & CUSTOM LISTS API
// ============================================================

export interface FanvueList {
    uuid: string;
    name: string;
    memberCount: number;
    type: 'smart' | 'custom';
}

export interface FanvueListMember {
    userUuid: string;
    username?: string;
    displayName?: string;
}

/**
 * Get Smart Lists for a creator
 * These are Fanvue's built-in lists (All contacts, Online, Followers, etc.)
 */
export const getSmartLists = async (
    creatorUserUuid: string,
    accessToken: string
): Promise<FanvueList[]> => {
    const baseUrl = Deno.env.get("FANVUE_API_BASE_URL") ?? "https://api.fanvue.com";
    const apiVersion = Deno.env.get("FANVUE_API_VERSION") ?? "2025-06-26";

    const url = `${baseUrl.replace(/\/$/, "")}/creators/${encodeURIComponent(creatorUserUuid)}/chats/lists/smart`;

    console.log(`📋 [getSmartLists] URL: ${url}`);

    const resp = await fetch(url, {
        method: "GET",
        headers: {
            "Authorization": `Bearer ${accessToken}`,
            "X-Fanvue-API-Version": apiVersion,
        },
    });

    const raw = await resp.text();
    console.log(`📋 [getSmartLists] Response (${resp.status}): ${raw.substring(0, 500)}`);

    if (!resp.ok) {
        throw new Error(`Fanvue getSmartLists failed ${resp.status}: ${raw}`);
    }

    try {
        const json = JSON.parse(raw) as any;
        // Map Fanvue response to our format
        const lists = json.data || json.lists || json || [];
        return lists.map((list: any) => ({
            uuid: list.uuid || list.id,
            name: list.name || list.title,
            memberCount: list.memberCount || list.members || list.count || 0,
            type: 'smart' as const,
        }));
    } catch (e) {
        console.error("Failed to parse smart lists:", e, raw);
        return [];
    }
};

/**
 * Get Custom Lists for a creator
 * These are user-created lists
 */
export const getCustomLists = async (
    creatorUserUuid: string,
    accessToken: string
): Promise<FanvueList[]> => {
    const baseUrl = Deno.env.get("FANVUE_API_BASE_URL") ?? "https://api.fanvue.com";
    const apiVersion = Deno.env.get("FANVUE_API_VERSION") ?? "2025-06-26";

    const url = `${baseUrl.replace(/\/$/, "")}/creators/${encodeURIComponent(creatorUserUuid)}/chats/lists/custom`;

    const resp = await fetch(url, {
        method: "GET",
        headers: {
            "Authorization": `Bearer ${accessToken}`,
            "X-Fanvue-API-Version": apiVersion,
        },
    });

    const raw = await resp.text();

    if (!resp.ok) {
        throw new Error(`Fanvue getCustomLists failed ${resp.status}: ${raw}`);
    }

    try {
        const json = JSON.parse(raw) as any;
        const lists = json.data || json.lists || json || [];
        return lists.map((list: any) => ({
            uuid: list.uuid || list.id,
            name: list.name || list.title,
            memberCount: list.memberCount || list.members || list.count || 0,
            type: 'custom' as const,
        }));
    } catch (e) {
        console.error("Failed to parse custom lists:", e, raw);
        return [];
    }
};

/**
 * Get members of a specific list
 * Works for both smart and custom lists
 */
export const getListMembers = async (
    creatorUserUuid: string,
    listUuid: string,
    listType: 'smart' | 'custom',
    accessToken: string
): Promise<FanvueListMember[]> => {
    const baseUrl = Deno.env.get("FANVUE_API_BASE_URL") ?? "https://api.fanvue.com";
    const apiVersion = Deno.env.get("FANVUE_API_VERSION") ?? "2025-06-26";

    const url = `${baseUrl.replace(/\/$/, "")}/creators/${encodeURIComponent(creatorUserUuid)}/chats/lists/${listType}/${encodeURIComponent(listUuid)}/members`;

    const resp = await fetch(url, {
        method: "GET",
        headers: {
            "Authorization": `Bearer ${accessToken}`,
            "X-Fanvue-API-Version": apiVersion,
        },
    });

    const raw = await resp.text();

    if (!resp.ok) {
        throw new Error(`Fanvue getListMembers failed ${resp.status}: ${raw}`);
    }

    try {
        const json = JSON.parse(raw) as any;
        const members = json.data || json.members || json || [];
        return members.map((member: any) => ({
            userUuid: member.userUuid || member.uuid || member.id,
            username: member.username,
            displayName: member.displayName || member.name,
        }));
    } catch (e) {
        console.error("Failed to parse list members:", e, raw);
        return [];
    }
};


