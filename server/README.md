# Safesight API

Node server that holds the **Gemini API key** and exposes `POST /v1/analyze` for the iOS app.

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/health` | Liveness |
| `POST` | `/v1/analyze` | Multipart: `meta` (JSON) + `image` (JPEG) → scan JSON |

The response shape matches the app’s `ScanAnalysisResponse`.

## Env

Copy `.env.example` → `.env` and set `GEMINI_API_KEY`.

Default port: **8787**.
