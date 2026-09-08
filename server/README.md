# Safesight API

Node server that holds the **Gemini API key** and exposes `POST /v1/analyze` for the iOS app.

Repo: [NoahWhiteson/Safesight_API](https://github.com/NoahWhiteson/Safesight_API)

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/health` | Liveness (no auth) |
| `POST` | `/v1/analyze` | Multipart: `meta` (JSON) + `image` (JPEG) → scan JSON |

`/v1/analyze` requires a shared secret. Send either:

```http
Authorization: Bearer <SAFESIGHT_API_SECRET>
```

or

```http
X-Safesight-Key: <SAFESIGHT_API_SECRET>
```

There is also a per-IP hourly rate limit (default **40**/hour).

The response shape matches the app’s `ScanAnalysisResponse`. Each hazard includes `confidence` (0–100) for the on-photo accuracy metre.

## Env

Copy `.env.example` → `.env` and set:

| Variable | Required | Notes |
|----------|----------|--------|
| `GEMINI_API_KEY` | **yes** | Google Gemini API key |
| `SAFESIGHT_API_SECRET` | **yes** | Shared with the iOS app |
| `GEMINI_MODEL` | no | Defaults in `.env.example` |
| `PORT` | no | Default **8787** |
| `SAFESIGHT_RATE_LIMIT_PER_HOUR` | no | Default **40** |

```bash
npm install
npm start
```
