# Safesight API

Node server that holds the **Gemini API key** and exposes `POST /v1/analyze` for the iOS app.

Repo: [NoahWhiteson/Safesight_API](https://github.com/NoahWhiteson/Safesight_API)

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/health` | Liveness |
| `POST` | `/v1/analyze` | Multipart: `meta` (JSON) + `image` (JPEG) → scan JSON |

The response shape matches the app’s `ScanAnalysisResponse`. Each hazard includes `confidence` (0–100) for the on-photo accuracy metre.

## Env

Copy `.env.example` → `.env` and set:

| Variable | Required | Notes |
|----------|----------|--------|
| `GEMINI_API_KEY` | **yes** | Google Gemini API key |
| `GEMINI_MODEL` | no | Defaults in `.env.example` |
| `PORT` | no | Default **8787** |

```bash
npm install
npm start
```
