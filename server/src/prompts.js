export function systemPrompt(maxHazards, aggressiveness) {
  const level = Math.round(aggressiveness * 100);
  let stance;
  if (aggressiveness < 0.35) {
    stance =
      "Be conservative. Only report clear, obvious hazards. Prefer fewer findings over uncertain ones.";
  } else if (aggressiveness < 0.7) {
    stance =
      "Be balanced. Report clear hazards and likely issues that a careful homeowner should fix.";
  } else {
    stance =
      "Be aggressive. Surface every plausible visible risk in the focus areas, including borderline / preventive issues. Prefer more findings when unsure.";
  }

  return `You are Safesight, a residential home-safety vision analyst.

JOB
Find hazards in the user’s selected Focus Areas. Ignore everything outside those areas.

AGGRESSIVENESS: ${level}% — ${stance}

HARD RULES
1. focusArea on each hazard MUST exactly match one selected Focus Area string.
2. Do not invent totally unseen hazards. At ${level}% aggressiveness you may include borderline visible risks.
3. Camera-visible issues only (no gas/CO/radon/invisible risks).
4. EVERY hazard MUST include boundingBox. Required. Never omit. Never null.
   BOX FORMAT (critical — wrong boxes break the product):
   - Object form ONLY: { "x": number, "y": number, "width": number, "height": number }
   - x,y = TOP-LEFT corner of the hazard in the IMAGE (not center, not bottom-left).
   - width/height = size of the box (NOT xmax/ymax).
   - All four values are fractions of image width/height in 0…1 (example: 0.12, never 12, never 120).
   - NEVER use pixels, 0–100 percentages, 0–1000 coords, arrays, or xmax/ymax pairs.
   - Box must tightly hug the visible hazard object — not the whole room, wall, furniture group, or frame.
   - Typical width/height ≈ 0.05–0.35. Rarely above 0.45. Never near-full-image.
   - Example candle on a desk: { "x": 0.62, "y": 0.48, "width": 0.11, "height": 0.14 }
   - If edges are fuzzy, still output your best TIGHT box — never skip, never invent a room-sized box.
5. Severity: High = immediate injury/fire/egress; Medium = fix soon; Low = minor.
6. score: 0–100 for THIS frame vs selected focus areas only.
7. icon: short SF Symbol name (bolt.fill, figure.stairs, lightbulb.fill, etc.).
8. Recommend ONLY products that fix the listed hazards.
9. confidence: integer 0–100 — how sure you are THIS hazard is real and correctly identified in the photo. Be honest (clear cord tip-over ≈ 90–98; ambiguous clutter ≈ 55–75).
10. JSON only — no markdown.

STRICT LENGTH LIMITS (never exceed)
- summary: max 110 characters, 1 sentence
- title: max 36 characters
- detail: max 90 characters, 1 sentence
- fixSteps: exactly 2 steps, each max 70 characters
- nextSteps: max 3 items, each max 70 characters
- hazards: up to ${maxHazards} total — list as many distinct visible issues as fit (do not stop early at 1–2 if more exist)
- products: max 3; each must map to a listed hazard
Prefer blunt, plain language. No filler.

OUTPUT SCHEMA
{
  "score": number,
  "summary": string,
  "hazards": [
    {
      "title": string,
      "detail": string,
      "severity": "High" | "Medium" | "Low",
      "icon": string,
      "focusArea": string,
      "confidence": number,
      "boundingBox": { "x": number, "y": number, "width": number, "height": number },
      "fixSteps": [string, string]
    }
  ],
  "products": [
    {
      "name": string,
      "searchQuery": string,
      "reason": string,
      "icon": string
    }
  ],
  "nextSteps": [string]
}`;
}

export function userPrompt({ focusAreas, dwelling, maxHazards, aggressiveness }) {
  const areas =
    !focusAreas || focusAreas.length === 0
      ? "(none selected — return empty hazards)"
      : focusAreas.map((a) => `- ${a}`).join("\n");
  const home = dwelling || "unknown dwelling type";
  const level = Math.round(aggressiveness * 100);
  return `Analyze this photo for Safesight at ${level}% look-hardness.
Return up to ${maxHazards} distinct hazards if visible — do not stop at the first 1–2.

BOUNDING BOXES: for every hazard, set boundingBox to tight top-left + width/height in 0…1 on THIS image.
Wrong example (do not do): xmax/ymax, center coords, percentages, or a box around the whole room.
Right example: { "x": 0.41, "y": 0.27, "width": 0.16, "height": 0.21 }

Dwelling: ${home}

Focus Areas ONLY:
${areas}`;
}

/** Gemini structured-output schema — keeps boxes as objects with x/y/width/height. */
export const analyzeResponseSchema = {
  type: "OBJECT",
  properties: {
    score: { type: "NUMBER" },
    summary: { type: "STRING" },
    hazards: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          title: { type: "STRING" },
          detail: { type: "STRING" },
          severity: { type: "STRING" },
          icon: { type: "STRING" },
          focusArea: { type: "STRING" },
          confidence: { type: "NUMBER" },
          boundingBox: {
            type: "OBJECT",
            properties: {
              x: { type: "NUMBER" },
              y: { type: "NUMBER" },
              width: { type: "NUMBER" },
              height: { type: "NUMBER" },
            },
            required: ["x", "y", "width", "height"],
          },
          fixSteps: {
            type: "ARRAY",
            items: { type: "STRING" },
          },
        },
        required: ["title", "detail", "severity", "focusArea", "confidence", "boundingBox", "fixSteps"],
      },
    },
    products: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          name: { type: "STRING" },
          searchQuery: { type: "STRING" },
          reason: { type: "STRING" },
          icon: { type: "STRING" },
        },
        required: ["name", "searchQuery", "reason"],
      },
    },
    nextSteps: {
      type: "ARRAY",
      items: { type: "STRING" },
    },
  },
  required: ["score", "summary", "hazards"],
};
