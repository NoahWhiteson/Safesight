import { randomUUID } from "crypto";

function clamp01(v) {
  return Math.min(1, Math.max(0, v));
}

function trimTo(text, max) {
  const t = String(text ?? "").trim();
  if (t.length <= max) return t;
  return t.slice(0, max - 1).trimEnd() + "…";
}

function normalizeBoxUnits(sx, sy, sw, sh) {
  const maxV = Math.max(sx, sy, sw, sh);
  // 0…1000 (or pixel-ish on ~1k images)
  if (maxV > 100) {
    return { sx: sx / 1000, sy: sy / 1000, sw: sw / 1000, sh: sh / 1000 };
  }
  // 0…100 percentages — only when clearly not already normalized
  if (maxV > 1.5) {
    return { sx: sx / 100, sy: sy / 100, sw: sw / 100, sh: sh / 100 };
  }
  return { sx, sy, sw, sh };
}

function fallbackBox(index, total) {
  const n = Math.max(total, 1);
  const spread = Math.min(0.18, 0.06 * (n - 1));
  const offset = (index - (n - 1) / 2) * (spread / Math.max(n - 1, 1));
  return {
    x: clamp01(0.34 + offset),
    y: clamp01(0.36 + offset * 0.4),
    width: 0.28,
    height: 0.22,
  };
}

function sanitizeBox(box, index, total) {
  let raw = box;
  if (Array.isArray(box) && box.length >= 4) {
    raw = { x: box[0], y: box[1], width: box[2], height: box[3] };
  }

  let x = raw?.x;
  let y = raw?.y;
  let width = raw?.width ?? raw?.w;
  let height = raw?.height ?? raw?.h;

  if (x == null && raw?.xmin != null) x = raw.xmin;
  if (y == null && raw?.ymin != null) y = raw.ymin;
  if (width == null && raw?.xmin != null && raw?.xmax != null) width = raw.xmax - raw.xmin;
  if (height == null && raw?.ymin != null && raw?.ymax != null) height = raw.ymax - raw.ymin;

  const missing = x == null || y == null || width == null || height == null;
  let sx = Number(x) || 0;
  let sy = Number(y) || 0;
  let sw = Number(width) || 0;
  let sh = Number(height) || 0;

  ({ sx, sy, sw, sh } = normalizeBoxUnits(sx, sy, sw, sh));

  sx = clamp01(sx);
  sy = clamp01(sy);
  sw = Math.max(0, sw);
  sh = Math.max(0, sh);

  const zeroed = sw < 0.01 || sh < 0.01;
  const nearlyFull = sw > 0.95 && sh > 0.95;
  if (missing || zeroed || nearlyFull) {
    return fallbackBox(index, total);
  }

  sw = Math.min(sw, 1 - sx);
  sh = Math.min(sh, 1 - sy);
  if (sw < 0.01 || sh < 0.01) {
    return fallbackBox(index, total);
  }
  return { x: sx, y: sy, width: sw, height: sh };
}

function sanitizeConfidence(raw) {
  let n = Number(raw);
  if (!Number.isFinite(n)) return 72;
  // Model sometimes returns 0…1
  if (n > 0 && n <= 1) n *= 100;
  return Math.min(99, Math.max(40, Math.round(n)));
}

function defaultIcon(focus) {
  const map = {
    Fire: "flame.fill",
    "Water leaks": "drop.fill",
    Electric: "bolt.fill",
    "Child proofing": "figure.and.child.holdinghands",
    "Trip hazards": "figure.walk",
    "Blocked exits": "door.left.hand.open",
  };
  return map[focus] || "exclamationmark.triangle.fill";
}

/**
 * Map Gemini JSON → iOS ScanAnalysisResponse.
 */
export function toScanAnalysisResponse(payload, { allowedFocusAreas, maxHazards }) {
  const allowed = new Set(allowedFocusAreas || []);
  const cap = Math.max(2, Math.min(8, maxHazards || 4));
  const rawHazards = Array.isArray(payload?.hazards) ? payload.hazards : [];

  const mappedHazards = [];
  for (let index = 0; index < rawHazards.length; index++) {
    const h = rawHazards[index];
    const title = String(h?.title ?? "").trim();
    if (!title) continue;

    const focus = h?.focusArea != null ? String(h.focusArea).trim() : null;
    if (allowed.size > 0) {
      if (!focus || !allowed.has(focus)) continue;
    }

    const severityRaw = h?.severity ?? "Medium";
    const severity =
      severityRaw === "High" || severityRaw === "Low" || severityRaw === "Medium"
        ? severityRaw
        : "Medium";

    const box = h?.boundingBox || h?.bounding_box || h?.bbox || {};
    const steps = (Array.isArray(h?.fixSteps) ? h.fixSteps : [])
      .map((s) => trimTo(s, 70))
      .filter(Boolean);
    const clampedSteps = (steps.length ? steps : ["Inspect and fix this issue."]).slice(0, 2);

    mappedHazards.push({
      id: randomUUID(),
      title: trimTo(title, 36),
      detail: trimTo(h?.detail ?? "", 90),
      severity,
      icon: h?.icon && String(h.icon).trim() ? String(h.icon).trim() : defaultIcon(focus),
      boundingBox: sanitizeBox(box, index, rawHazards.length),
      fixSteps: clampedSteps,
      focusArea: focus,
      confidence: sanitizeConfidence(h?.confidence ?? h?.accuracy ?? h?.certainty),
      status: "open",
    });
  }

  const limitedHazards = mappedHazards.slice(0, cap);
  const scoreRaw = payload?.score;
  const score = Math.min(
    100,
    Math.max(
      0,
      typeof scoreRaw === "number"
        ? Math.round(scoreRaw)
        : limitedHazards.length === 0
          ? 92
          : 70
    )
  );

  let summary = String(payload?.summary ?? "").trim();
  if (!summary) {
    summary =
      limitedHazards.length === 0
        ? "No issues found in your selected focus areas."
        : `Found ${limitedHazards.length} issue${limitedHazards.length === 1 ? "" : "s"} in your focus areas.`;
  }
  summary = trimTo(summary, 110);

  const nextSteps = (Array.isArray(payload?.nextSteps) ? payload.nextSteps : [])
    .map((s) => trimTo(s, 70))
    .filter(Boolean)
    .slice(0, 3);

  const products = (Array.isArray(payload?.products) ? payload.products : [])
    .map((p) => {
      const name = String(p?.name ?? "").trim();
      if (!name) return null;
      return {
        id: randomUUID(),
        name: trimTo(name, 42),
        reason: trimTo(p?.reason ?? "", 70),
        priceLabel: "Shop on Amazon",
        icon: p?.icon && String(p.icon).trim() ? String(p.icon).trim() : "cart.fill",
        searchQuery: p?.searchQuery ? trimTo(p.searchQuery, 80) : null,
      };
    })
    .filter(Boolean)
    .slice(0, 3);

  return {
    score,
    summary,
    hazards: limitedHazards,
    products,
    nextSteps,
  };
}

export function stripCodeFences(raw) {
  let text = String(raw ?? "").trim();
  if (text.startsWith("```")) {
    text = text.replace(/^```json\s*/i, "").replace(/^```\s*/i, "");
    text = text.replace(/```$/i, "").trim();
  }
  return text;
}
