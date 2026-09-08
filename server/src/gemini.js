import { systemPrompt, userPrompt, analyzeResponseSchema } from "./prompts.js";
import { stripCodeFences, toScanAnalysisResponse } from "./mapResponse.js";

export async function analyzeWithGemini({
  apiKey,
  model,
  imageBuffer,
  focusAreas,
  dwelling,
  aggressiveness,
  maxHazards,
}) {
  const cap = Math.max(2, Math.min(8, maxHazards || 4));
  const agg = Math.min(1, Math.max(0.1, aggressiveness ?? 0.55));
  const jpegBase64 = imageBuffer.toString("base64");

  // Keep temperature low — box geometry is sensitive to sampling noise.
  const temperature = agg >= 0.7 ? 0.22 : 0.12;

  const body = {
    system_instruction: {
      parts: [{ text: systemPrompt(cap, agg) }],
    },
    contents: [
      {
        role: "user",
        parts: [
          {
            text: userPrompt({
              focusAreas: focusAreas || [],
              dwelling,
              maxHazards: cap,
              aggressiveness: agg,
            }),
          },
          {
            inline_data: {
              mime_type: "image/jpeg",
              data: jpegBase64,
            },
          },
        ],
      },
    ],
    generation_config: {
      temperature,
      response_mime_type: "application/json",
      response_schema: analyzeResponseSchema,
      thinking_config: { thinking_level: "LOW" },
    },
  };

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

  let lastError;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });

      const textBody = await res.text();
      if (!res.ok) {
        if ((res.status === 429 || res.status >= 500) && attempt < 3) {
          await new Promise((r) => setTimeout(r, attempt * 700));
          continue;
        }
        const err = new Error(`Gemini HTTP ${res.status}`);
        err.status = res.status;
        err.detail = textBody.slice(0, 500);
        throw err;
      }

      const envelope = JSON.parse(textBody);
      const rawText =
        envelope?.candidates?.[0]?.content?.parts?.map((p) => p.text).find(Boolean) ?? "";
      if (!rawText) {
        throw new Error("Gemini returned empty text");
      }

      const cleaned = stripCodeFences(rawText);
      const payload = JSON.parse(cleaned);
      return toScanAnalysisResponse(payload, {
        allowedFocusAreas: focusAreas || [],
        maxHazards: cap,
      });
    } catch (error) {
      lastError = error;
      const retryable =
        error?.cause?.code === "ECONNRESET" ||
        error?.cause?.code === "ETIMEDOUT" ||
        error?.name === "TimeoutError";
      if (retryable && attempt < 3) {
        await new Promise((r) => setTimeout(r, attempt * 600));
        continue;
      }
      if (error.status && attempt < 3 && (error.status === 429 || error.status >= 500)) {
        await new Promise((r) => setTimeout(r, attempt * 700));
        continue;
      }
      throw error;
    }
  }
  throw lastError || new Error("Gemini failed");
}
