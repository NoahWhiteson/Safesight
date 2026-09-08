import { randomUUID } from "crypto";

function clamp01(v) {
  return Math.min(1, Math.max(0, v));
}

function trimTo(text, max) {
  const t = String(text ?? "").trim();
  if (t.length <= max) return t;
  return t.slice(0, max - 1).trimEnd() + "…";
}

function num(v) {
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

/**
 * Gemini sometimes returns xyxy, center boxes, 0–100, or 0–1000.
 * Normalize everything to top-left + size in 0…1.
 */
function coerceRawBox(box) {
  if (box == null) return null;

  if (Array.isArray(box) && box.length >= 4) {
    const a = num(box[0]);
    const b = num(box[1]);
    const c = num(box[2]);
    const d = num(box[3]);
    if (a == null || b == null || c == null || d == null) return null;

    // [xmin, ymin, xmax, ymax] — third/fourth look like corners, not sizes
    const looksXyxy =
      c > a &&
      d > b &&
      (c - a) >= 0.01 &&
      (d - b) >= 0.01 &&
      (a + c > 1.02 || b + d > 1.02 || c > 0.7 || d > 0.7 || c > 1 || d > 1);
    if (looksXyxy) {
      return { x: a, y: b, width: c - a, height: d - b };
    }
    return { x: a, y: b, width: c, height: d };
  }

  if (typeof box !== "object") return null;

  const cx = num(box.centerX ?? box.cx ?? box.center_x);
  const cy = num(box.centerY ?? box.cy ?? box.center_y);
  let width = num(box.width ?? box.w);
  let height = num(box.height ?? box.h);

  if (cx != null && cy != null && width != null && height != null) {
    return { x: cx - width / 2, y: cy - height / 2, width, height };
  }

  let x = num(box.x ?? box.left ?? box.x_min ?? box.xmin);
  let y = num(box.y ?? box.top ?? box.y_min ?? box.ymin);
  const x2 = num(box.x2 ?? box.right ?? box.x_max ?? box.xmax);
  const y2 = num(box.y2 ?? box.bottom ?? box.y_max ?? box.ymax);

  if (width == null && x != null && x2 != null) width = x2 - x;
  if (height == null && y != null && y2 != null) height = y2 - y;

  if (x == null || y == null || width == null || height == null) return null;
  return { x, y, width, height };
}

function normalizeBoxUnits(sx, sy, sw, sh) {
  const maxV = Math.max(Math.abs(sx), Math.abs(sy), Math.abs(sw), Math.abs(sh));
  if (maxV > 100) {
    return { sx: sx / 1000, sy: sy / 1000, sw: sw / 1000, sh: sh / 1000 };
  }
  if (maxV > 1.5) {
    return { sx: sx / 100, sy: sy / 100, sw: sw / 100, sh: sh / 100 };
  }
  return { sx, sy, sw, sh };
}

/** Prefer a tightened real box over a fake center fallback. */
function tightenBox(sx, sy, sw, sh) {
  const maxW = 0.52;
  const maxH = 0.52;
  let x = sx;
  let y = sy;
  let w = sw;
  let h = sh;

  if (w > maxW) {
    const cx = x + w / 2;
    w = maxW;
    x = cx - w / 2;
  }
  if (h > maxH) {
    const cy = y + h / 2;
    h = maxH;
    y = cy - h / 2;
  }

  x = clamp01(x);
  y = clamp01(y);
  w = Math.min(Math.max(w, 0.04), 1 - x);
  h = Math.min(Math.max(h, 0.04), 1 - y);
  return { x, y, width: w, height: h };
}

function fallbackBox(index, total) {
  const n = Math.max(total, 1);
  const spread = Math.min(0.18, 0.06 * (n - 1));
  const offset = (index - (n - 1) / 2) * (spread / Math.max(n - 1, 1));
  return {
    x: clamp01(0.34 + offset),
    y: clamp01(0.36 + offset * 0.4),
    width: 0.22,
    height: 0.18,
  };
}

export function sanitizeBox(box, index, total) {
  const coerced = coerceRawBox(box);
  if (!coerced) return fallbackBox(index, total);

  let sx = coerced.x;
  let sy = coerced.y;
  let sw = coerced.width;
  let sh = coerced.height;

  ({ sx, sy, sw, sh } = normalizeBoxUnits(sx, sy, sw, sh));

  // Absolute junk only → fallback
  if (!Number.isFinite(sx) || !Number.isFinite(sy) || !Number.isFinite(sw) || !Number.isFinite(sh)) {
    return fallbackBox(index, total);
  }
  if (sw <= 0 || sh <= 0) return fallbackBox(index, total);

  // Negative origin sometimes means center-ish mistakes — snap into view first
  if (sx < 0) {
    sw += sx;
    sx = 0;
  }
  if (sy < 0) {
    sh += sy;
    sy = 0;
  }

  sx = clamp01(sx);
  sy = clamp01(sy);
  sw = Math.max(0, sw);
  sh = Math.max(0, sh);

  if (sw < 0.012 || sh < 0.012) return fallbackBox(index, total);

  // Huge / full-frame → tighten around center instead of inventing a new box
  if (sw > 0.72 || sh > 0.72 || (sw > 0.55 && sh > 0.55)) {
    return tightenBox(sx, sy, sw, sh);
  }

  sw = Math.min(sw, 1 - sx);
  sh = Math.min(sh, 1 - sy);
  if (sw < 0.012 || sh < 0.012) return fallbackBox(index, total);

  // Floor tiny but real boxes so overlays stay tappable
  if (sw < 0.04) {
    const cx = sx + sw / 2;
    sw = 0.04;
    sx = clamp01(cx - sw / 2);
    sw = Math.min(sw, 1 - sx);
  }
  if (sh < 0.04) {
    const cy = sy + sh / 2;
    sh = 0.04;
    sy = clamp01(cy - sh / 2);
    sh = Math.min(sh, 1 - sy);
  }

  return { x: sx, y: sy, width: sw, height: sh };
}

function sanitizeConfidence(raw) {
  let n = Number(raw);
  if (!Number.isFinite(n)) return 72;
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

    const box = h?.boundingBox || h?.bounding_box || h?.bbox || h?.box || {};
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
