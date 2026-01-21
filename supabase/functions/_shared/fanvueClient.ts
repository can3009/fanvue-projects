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


