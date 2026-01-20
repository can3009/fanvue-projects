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
