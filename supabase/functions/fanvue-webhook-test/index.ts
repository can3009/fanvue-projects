/// <reference lib="deno.ns" />
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { crypto } from "https://deno.land/std@0.177.0/crypto/mod.ts";

/**
 * fanvue-webhook-test
 * 
 * Purpose: Test webhook endpoint by sending a signed test payload
 * Auth: Verify JWT ON (authenticated users only)
 * 
 * Input: { creatorId: string } OR uses auth.uid()
 * Output: Test result with signature validation status
 */

const CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function isValidUUID(str: string): boolean {
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    return uuidRegex.test(str);
}

async function signPayload(payload: string, secret: string): Promise<string> {
    const timestamp = Math.floor(Date.now() / 1000).toString();
    const signedPayload = `${timestamp}.${payload}`;

    const key = await crypto.subtle.importKey(
        "raw",
        new TextEncoder().encode(secret),
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["sign"]
    );

    const signature = await crypto.subtle.sign(
        "HMAC",
        key,
        new TextEncoder().encode(signedPayload)
    );

    const signatureHex = Array.from(new Uint8Array(signature))
        .map((b) => b.toString(16).padStart(2, "0"))
        .join("");

    return `t=${timestamp},v0=${signatureHex}`;
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: CORS_HEADERS });
    }

    if (req.method !== "POST") {
        return new Response(
            JSON.stringify({ error: "Method not allowed" }),
            { status: 405, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
        return new Response(
            JSON.stringify({ error: "Server configuration error" }),
            { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
    }

    try {
        // Get creatorId from body or auth
        let creatorId: string | null = null;

        const body = await req.json().catch(() => ({}));
        creatorId = body.creatorId;

        // If no creatorId in body, try to get from auth
        if (!creatorId) {
            const authHeader = req.headers.get("Authorization");
            if (authHeader) {
                const supabaseAuth = createClient(supabaseUrl, serviceRoleKey);
                const token = authHeader.replace("Bearer ", "");
                const { data: { user } } = await supabaseAuth.auth.getUser(token);
                if (user) {
                    creatorId = user.id;
                }
            }
        }

        if (!creatorId || !isValidUUID(creatorId)) {
            return new Response(
                JSON.stringify({ error: "Missing or invalid creatorId" }),
                { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
            );
        }

        console.log("🧪 Testing webhook for creator:", creatorId);

        const supabase = createClient(supabaseUrl, serviceRoleKey);

        // Get webhook secret for this creator
        const { data: integration, error: integrationError } = await supabase
            .from("creator_integrations")
            .select("fanvue_webhook_secret")
            .eq("creator_id", creatorId)
            .eq("integration_type", "fanvue")
            .single();

        if (integrationError || !integration) {
            return new Response(
                JSON.stringify({
                    success: false,
                    error: "Integration not found - please complete setup first"
                }),
                { status: 404, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
            );
        }

        const webhookSecret = integration.fanvue_webhook_secret || "";

        if (!webhookSecret) {
            return new Response(
                JSON.stringify({
                    success: false,
                    error: "Webhook secret not configured"
                }),
                { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
            );
        }

        // Create test payload
        const testPayload = {
            event: "webhook.test",
            data: {
                id: `test_${Date.now()}`,
                senderId: "test_fan_id_12345",
                senderUsername: "TestFan",
                content: "This is a test webhook message",
                timestamp: new Date().toISOString(),
            },
        };

        const payloadString = JSON.stringify(testPayload);

        // Sign the payload using Fanvue's format
        const signatureHeader = await signPayload(payloadString, webhookSecret);

        // Build webhook URL
        const projectRef = supabaseUrl.replace("https://", "").split(".")[0];
        const webhookUrl = `https://${projectRef}.supabase.co/functions/v1/fanvue-webhook?creatorId=${creatorId}`;

        console.log("📤 Sending test webhook to:", webhookUrl);

        // Call the webhook endpoint
        const webhookResponse = await fetch(webhookUrl, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "X-Fanvue-Signature": signatureHeader,
            },
            body: payloadString,
        });

        const webhookResult = await webhookResponse.json();

        const testResult = {
            success: webhookResponse.ok,
            status: webhookResponse.status,
            signatureValid: webhookResponse.status !== 401,
            webhookUrl: webhookUrl,
            testPayload: testPayload,
            response: webhookResult,
            testedAt: new Date().toISOString(),
        };

        console.log("✅ Webhook test complete:", testResult.success ? "SUCCESS" : "FAILED");

        return new Response(
            JSON.stringify(testResult),
            {
                status: testResult.success ? 200 : 400,
                headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
            }
        );

    } catch (error) {
        console.error("❌ Webhook Test Error:", error);
        return new Response(
            JSON.stringify({ error: String(error), success: false }),
            { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
    }
});
