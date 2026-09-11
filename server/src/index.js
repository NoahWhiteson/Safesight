import "dotenv/config";
import cors from "cors";
import crypto from "crypto";
import express from "express";
import multer from "multer";
import path from "path";
import { fileURLToPath } from "url";
import { analyzeWithGemini } from "./gemini.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PUBLIC_DIR = path.join(__dirname, "../public");
const DEMO_VIDEO = path.join(PUBLIC_DIR, "demovideo.mp4");

const PORT = Number(process.env.PORT || 8787);
const GEMINI_API_KEY = (process.env.GEMINI_API_KEY || "").trim();
const GEMINI_MODEL = (process.env.GEMINI_MODEL || "gemini-3.8-flash").trim();
const API_SECRET = (process.env.SAFESIGHT_API_SECRET || "").trim();

/** Soft cap so a leaked client key still can't freely burn Gemini. */
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;
const RATE_LIMIT_MAX = Number(process.env.SAFESIGHT_RATE_LIMIT_PER_HOUR || 40);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 12 * 1024 * 1024 },
});

const app = express();
app.use(cors());
app.use(express.json({ limit: "1mb" }));

const rateBuckets = new Map();

function clientIp(req) {
  const forwarded = req.headers["x-forwarded-for"];
  if (typeof forwarded === "string" && forwarded.length) {
    return forwarded.split(",")[0].trim();
  }
  return req.socket.remoteAddress || "unknown";
}

function timingSafeEqualString(a, b) {
  const left = Buffer.from(String(a));
  const right = Buffer.from(String(b));
  if (left.length !== right.length) {
    // Still run a compare to keep timing flatter on length mismatch.
    crypto.timingSafeEqual(left, Buffer.alloc(left.length));
    return false;
  }
  return crypto.timingSafeEqual(left, right);
}

function requireApiSecret(req, res, next) {
  if (!API_SECRET) {
    return res.status(500).json({ error: "SAFESIGHT_API_SECRET not configured on server" });
  }

  const auth = req.get("authorization") || "";
  const bearer = auth.match(/^Bearer\s+(.+)$/i)?.[1]?.trim() || "";
  const headerKey = (req.get("x-safesight-key") || "").trim();
  const provided = bearer || headerKey;

  if (!provided || !timingSafeEqualString(provided, API_SECRET)) {
    return res.status(401).json({ error: "Unauthorized" });
  }
  return next();
}

function rateLimitAnalyze(req, res, next) {
  const ip = clientIp(req);
  const now = Date.now();
  let bucket = rateBuckets.get(ip);
  if (!bucket || now >= bucket.resetAt) {
    bucket = { count: 0, resetAt: now + RATE_LIMIT_WINDOW_MS };
    rateBuckets.set(ip, bucket);
  }
  bucket.count += 1;
  if (bucket.count > RATE_LIMIT_MAX) {
    const retryAfter = Math.max(1, Math.ceil((bucket.resetAt - now) / 1000));
    res.set("Retry-After", String(retryAfter));
    return res.status(429).json({
      error: "Rate limit exceeded",
      retryAfterSeconds: retryAfter,
    });
  }
  return next();
}

app.get("/health", (_req, res) => {
  res.json({
    ok: true,
    service: "safesight-api",
    model: GEMINI_MODEL,
    hasKey: Boolean(GEMINI_API_KEY),
    authRequired: Boolean(API_SECRET),
  });
});

/** Product demo MP4 at /demovideo (and /demovideo.mp4). */
function sendDemoVideo(req, res) {
  res.sendFile(DEMO_VIDEO, {
    acceptRanges: true,
    headers: {
      "Content-Type": "video/mp4",
      "Cache-Control": "public, max-age=86400",
    },
  }, (err) => {
    if (err && !res.headersSent) {
      res.status(404).json({ error: "Demo video not found" });
    }
  });
}

app.get(["/demovideo", "/demovideo/", "/demovideo.mp4"], sendDemoVideo);

/**
 * POST /v1/analyze
 * multipart: meta (JSON string of ScanAnalysisRequest fields) + image (jpeg)
 * Auth: Authorization: Bearer <SAFESIGHT_API_SECRET>  OR  X-Safesight-Key: <secret>
 */
app.post(
  "/v1/analyze",
  requireApiSecret,
  rateLimitAnalyze,
  upload.single("image"),
  async (req, res) => {
    try {
      if (!GEMINI_API_KEY) {
        return res.status(500).json({ error: "GEMINI_API_KEY not configured on server" });
      }
      if (!req.file?.buffer?.length) {
        return res.status(400).json({ error: "Missing image file" });
      }

      let meta = {};
      if (req.body?.meta) {
        meta = typeof req.body.meta === "string" ? JSON.parse(req.body.meta) : req.body.meta;
      } else if (req.body?.focusAreas) {
        meta = req.body;
      }

      const focusAreas = Array.isArray(meta.focusAreas) ? meta.focusAreas : [];
      const dwelling = meta.dwelling ?? null;
      const aggressiveness = Number(meta.aggressiveness ?? 0.55);
      const maxHazards = Number(meta.maxHazards ?? 4);

      const result = await analyzeWithGemini({
        apiKey: GEMINI_API_KEY,
        model: GEMINI_MODEL,
        imageBuffer: req.file.buffer,
        focusAreas,
        dwelling,
        aggressiveness,
        maxHazards,
      });

      res.json(result);
    } catch (error) {
      console.error("analyze failed:", error?.message || error, error?.detail || "");
      res.status(502).json({
        error: "Analysis failed",
        detail: error?.message || "unknown",
      });
    }
  }
);

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Safesight API listening on http://0.0.0.0:${PORT}`);
  if (!GEMINI_API_KEY) {
    console.warn("Warning: GEMINI_API_KEY is empty — set it in server/.env");
  }
  if (!API_SECRET) {
    console.warn("Warning: SAFESIGHT_API_SECRET is empty — /v1/analyze will reject all requests");
  }
});
