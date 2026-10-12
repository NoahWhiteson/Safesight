const ROUTE_SCHEMA = {
  type: "object",
  properties: {
    segments: {
      type: "array",
      items: {
        type: "object",
        properties: {
          room_label: { type: "string" },
          best_frame_index: { type: "integer" },
          confidence: { type: "number" },
        },
        required: ["room_label", "best_frame_index", "confidence"],
      },
    },
  },
  required: ["segments"],
};

const ROUTE_SYSTEM = (maxRooms) => `You route home walkthrough video frames into distinct indoor spaces.
Rules:
- Group frames that show the SAME room/space (ignore small camera angle changes).
- Pick ONE best_frame_index per space (sharpest, most representative).
- Use short human labels: kitchen, hallway, bathroom, bedroom, living room, etc.
- If unsure, use "space_1", "space_2".
- Return at most ${maxRooms} segments.
- If all frames are one room, return one segment.
- best_frame_index is 0-based index matching the order frames were sent (Frame 0, Frame 1, ...).`;

function stripCodeFences(text) {
  const trimmed = String(text || "").trim();
  const fenced = trimmed.match(/^```(?:json)?\s*([\s\S]*?)```$/i);
  return (fenced ? fenced[1] : trimmed).trim();
}

export async function routeVideoWithGemini({
  apiKey,
  model,
  imageBuffers,
  maxRooms = 4,
}) {
  const frames = imageBuffers.filter((b) => b?.length);
  if (!frames.length) {
    return { segments: [{ room_label: "space_1", best_frame_index: 0, confidence: 0.5 }] };
  }

  const cap = Math.max(1, Math.min(6, maxRooms || 4));
  const parts = [
    {
      text: `There are ${frames.length} frames labeled Frame 0 through Frame ${frames.length - 1}. Cluster by distinct room/space and pick the best frame index per space.`,
    },
  ];

  for (let i = 0; i < frames.length; i += 1) {
    parts.push({ text: `Frame ${i}:` });
    parts.push({
      inline_data: {
        mime_type: "image/jpeg",
        data: frames[i].toString("base64"),
      },
    });
  }

  const body = {
    system_instruction: {
      parts: [{ text: ROUTE_SYSTEM(cap) }],
    },
    contents: [{ role: "user", parts }],
    generation_config: {
      temperature: 0.1,
      response_mime_type: "application/json",
      response_schema: ROUTE_SCHEMA,
      thinking_config: { thinking_level: "MINIMAL" },
    },
  };

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  const textBody = await res.text();
  if (!res.ok) {
    const err = new Error(`Gemini route HTTP ${res.status}`);
    err.detail = textBody.slice(0, 500);
    throw err;
  }

  const envelope = JSON.parse(textBody);
  const rawText =
    envelope?.candidates?.[0]?.content?.parts?.map((p) => p.text).find(Boolean) ?? "";
  if (!rawText) {
    throw new Error("Gemini route returned empty text");
  }

  const payload = JSON.parse(stripCodeFences(rawText));
  let segments = Array.isArray(payload.segments) ? payload.segments : [];
  segments = segments
    .map((s) => ({
      room_label: String(s.room_label || "space").trim() || "space",
      best_frame_index: Number(s.best_frame_index),
      confidence: Number(s.confidence ?? 0.5),
    }))
    .filter(
      (s) =>
        Number.isFinite(s.best_frame_index) &&
        s.best_frame_index >= 0 &&
        s.best_frame_index < frames.length
    );

  if (!segments.length) {
    return { segments: [{ room_label: "space_1", best_frame_index: 0, confidence: 0.5 }] };
  }

  const seen = new Set();
  const deduped = [];
  for (const seg of segments) {
    if (seen.has(seg.best_frame_index)) continue;
    seen.add(seg.best_frame_index);
    deduped.push(seg);
    if (deduped.length >= cap) break;
  }

  return { segments: deduped };
}
