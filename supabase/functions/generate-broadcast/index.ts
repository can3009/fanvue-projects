import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createSupabaseServiceClient } from "../_shared/supabaseClient.ts";
import { CORS_HEADERS } from "../_shared/types.ts";

const LLM_BASE_URL = Deno.env.get("LLM_BASE_URL") || "https://api.x.ai/v1";
const LLM_MODEL = Deno.env.get("LLM_MODEL") || "grok-2-latest";
const LLM_API_KEY = Deno.env.get("LLM_API_KEY");

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: CORS_HEADERS });
    }

    try {
        if (!LLM_API_KEY) throw new Error("Missing LLM_API_KEY");

        const { creator_id, style, topic, language, length, excluded_words, use_emojis } = await req.json();

        if (!creator_id) throw new Error("Missing creator_id");

        // 1. Get Creator Info (for Name/Persona)
        const supabase = createSupabaseServiceClient();
        const { data: creator, error: creatorError } = await supabase
            .from("creators")
            .select("display_name")
            .eq("id", creator_id)
            .single();

        const creatorName = creator?.display_name || "Creator";

        // 2. Build Prompt
        const targetLang = language || "German";

        let lengthInstruction = "Target length: 6-16 words.";
        let styleInstruction = "Style: Engaging, personal.";

        if (length === "Short") {
            lengthInstruction = "STRICT LIMIT: 2-6 words maximum. Do not write more. Examples: 'Hey! New post is up!' or 'Miss you! Check DMs'.";
            styleInstruction = "Style: Direct, concise.";
        } else if (length === "Long") {
            lengthInstruction = "Target length: 24-34 words.";
        }

        let systemPrompt = `You are ${creatorName}, a popular Fanvue creator.`;
        systemPrompt += `\nTask: Write a message to fans.`;
        systemPrompt += `\nLanguage: ${targetLang}.`;
        systemPrompt += `\n${styleInstruction}`;

        if (use_emojis !== false) {
            systemPrompt += `\nUse emojis.`;
        } else {
            systemPrompt += `\nDO NOT use emojis.`;
        }

        if (excluded_words) {
            systemPrompt += `\nFORBIDDEN WORDS: ${excluded_words}.`;
        }

        // Add length instruction last in system prompt for higher weight
        systemPrompt += `\nCRITICAL INSTRUCTION: ${lengthInstruction}`;

        let userPrompt = "";

        const isShort = length === "Short";

        switch (style) {
            case 'tease':
                userPrompt = isShort ? "Tease new post." : "Write a playful tease.";
                break;
            case 'ppv':
                userPrompt = isShort ? "Sell PPV." : "Sell a new hot PPV video. Convince them.";
                break;
            case 're-engage':
                userPrompt = isShort ? "Message inactive fans." : "Message inactive fans. Miss you vibes.";
                break;
            case 'promo':
                userPrompt = isShort ? "Promote offer." : "Promote a discount or offer.";
                break;
            case 'morning':
                userPrompt = "Good Morning message.";
                break;
            case 'night':
                userPrompt = "Good Night message.";
                break;
            default:
                userPrompt = "Write a message to fans.";
        }

        if (topic) {
            userPrompt += ` Topic: ${topic}`;
        }

        // Reinforce constraints in user prompt for maximum adherence
        userPrompt += ` (${lengthInstruction})`;
        if (use_emojis === false) {
            userPrompt += ` (STRICTLY NO EMOJIS)`;
        }

        console.log(`🤖 Generating ${style} in ${targetLang} for ${creatorName}`);

        // 3. Call LLM
        const resp = await fetch(`${LLM_BASE_URL}/chat/completions`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${LLM_API_KEY}`
            },
            body: JSON.stringify({
                model: LLM_MODEL,
                messages: [
                    { role: "system", content: systemPrompt },
                    { role: "user", content: userPrompt }
                ],
                max_tokens: 300,
                temperature: 0.7
            })
        });

        if (!resp.ok) {
            const err = await resp.text();
            throw new Error(`LLM API Error: ${resp.status} ${err}`);
        }

        const completion = await resp.json();
        let generatedText = completion.choices[0]?.message?.content?.trim();

        // FORCE REMOVE EMOJIS if toggle is off (LLM can be stubborn)
        if (use_emojis === false && generatedText) {
            // Remove emojis using Unicode property escapes
            generatedText = generatedText.replace(/([\u2700-\u27BF]|[\uE000-\uF8FF]|\uD83C[\uDC00-\uDFFF]|\uD83D[\uDC00-\uDFFF]|[\u2011-\u26FF]|\uD83E[\uDD10-\uDDFF])/g, '')
                .replace(/\s+/g, ' ') // Fix double spaces left by removal
                .trim();
        }

        return new Response(
            JSON.stringify({ message: generatedText }),
            { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );

    } catch (error) {
        console.error("Generate Broadcast Error:", error);
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
    }
});
