import "dotenv/config";
import cors from "cors";
import express from "express";
import multer from "multer";
import { analyzeWithGemini } from "./gemini.js";

const PORT = Number(process.env.PORT || 8787);
const GEMINI_API_KEY = (process.env.GEMINI_API_KEY || "").trim();
const GEMINI_MODEL = (process.env.GEMINI_MODEL || "gemini-3.8-flash").trim();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 12 * 1024 * 1024 },
});

const app = express();
app.use(cors());
app.use(express.json({ limit: "1mb" }));

app.get("/health", (_req, res) => {
  res.json({
    ok: true,
    service: "safesight-api",
    model: GEMINI_MODEL,
    hasKey: Boolean(GEMINI_API_KEY),
  });
});

/**
 * POST /v1/analyze
 * multipart: meta (JSON string of ScanAnalysisRequest fields) + image (jpeg)
 */
app.post("/v1/analyze", upload.single("image"), async (req, res) => {
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
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Safesight API listening on http://0.0.0.0:${PORT}`);
  if (!GEMINI_API_KEY) {
    console.warn("Warning: GEMINI_API_KEY is empty — set it in server/.env");
  }
});
