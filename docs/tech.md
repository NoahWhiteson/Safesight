# Tech at a glance

| Layer | Choice |
|-------|--------|
| UI | SwiftUI (+ UIKit tab host) |
| API | Safesight server (`server/`) — Gemini key stays off-device |
| Vision | Google Gemini via `POST /v1/analyze` |
| Auth | Shared `SAFESIGHT_API_SECRET` (Bearer) + per-IP rate limit |
| Subscriptions | RevenueCat (`monthly` / `yearly` → `safesight_pro`) |
| Commerce hints | Amazon-style search picks tied to hazards |
| Persistence | On-device scan images + history index |

Server docs: [`server/README.md`](../server/README.md)

[← Back to README](../README.md)
