# Setup / run

Shipaton Next Gen is judged from the **demo video + this public repo**. You can open the Xcode project and review the full source without any secrets.

**Live scans are different:** the app talks to a Safesight API that holds the Gemini key. A clone alone cannot call the hosted production API — that shared secret is **not** in git (by design). To actually run a scan yourself, use the **self-serve local API** below (your own Gemini key + your own secret), or ask the author for temporary hosted access via the Devpost submission.

## Requirements

- macOS with **Xcode** (project deployment target: **iOS 26.5**)
- Simulator or device (photo **upload** works on Simulator; live camera needs a device)
- To run scans: **Node.js 18+** and a **Google Gemini API key** ([Google AI Studio](https://aistudio.google.com/apikey))

## 1. Clone and open

```bash
git clone https://github.com/NoahWhiteson/Safesight.git
cd Safesight
open Safesight.xcodeproj
```

## 2. Run a scan (self-serve — recommended for judges)

You do **not** need the production `SAFESIGHT_API_SECRET`. Spin up the API in `server/` with **your** Gemini key and **any** long random secret you invent; put that same secret in the app.

### 2a. Start the local API

```bash
cd server
cp .env.example .env
```

Edit `.env`:

| Variable | What to put |
|----------|-------------|
| `GEMINI_API_KEY` | Your key from Google AI Studio |
| `SAFESIGHT_API_SECRET` | Any long random string you choose (e.g. `openssl rand -hex 32`) |
| `PORT` | Optional; default `8787` |

```bash
npm install
npm start
```

Confirm: `GET http://127.0.0.1:8787/health`

More detail: [`server/README.md`](../server/README.md) · [Safesight_API](https://github.com/NoahWhiteson/Safesight_API)

### 2b. Point the iOS app at localhost

1. Copy secrets template:

```bash
cp Safesight/SafesightAPISecrets.example.plist Safesight/SafesightAPISecrets.plist
```

2. Set `API_SECRET` in that plist to the **same** string as `SAFESIGHT_API_SECRET` in `.env`.

3. In `Safesight/Info.plist`, add:

| Key | Type | Value |
|-----|------|--------|
| `SAFESIGHT_API_BASE_URL` | String | `http://127.0.0.1:8787` |

(`NSAllowsLocalNetworking` is already enabled for local HTTP.)

`SafesightAPISecrets.plist` is gitignored — never commit real secrets.

### 2c. Build & run

1. Select the **Safesight** scheme → Simulator or device  
2. `⌘R`  
3. Onboarding → **Scan** → capture or **upload** a room photo  

RevenueCat uses a **Test Store** key in `RevenueCatConfig.swift` (`safesight_pro`, products `monthly` / `yearly`). Paywall flows work without a paid Apple Developer account for Next Gen. Details: [RevenueCat / Premium](./revenuecat.md).

## 3. Hosted API (optional — not public)

Default base URL (if you omit `SAFESIGHT_API_BASE_URL`) is:

`https://safesight.noahwhiteson.com`

That endpoint still requires `Authorization: Bearer <SAFESIGHT_API_SECRET>` matching the **deployed** server. The production secret is **not** published in this repository.

- **Shipaton judges:** use §2 (local + your Gemini key), or request a short-lived secret via the Devpost project / author contact if you specifically need the hosted stack.  
- Without a matching secret, analyze fails → scan-failed drawer → **no free-scan credit charged**.

## 4. Permissions

- **Camera** — live capture  
- **Photo library** — upload  

## Quick check

| Check | Expected |
|-------|----------|
| Open project in Xcode | Builds; UI / RevenueCat reviewable with no secrets |
| Local `/health` | OK when `npm start` is running |
| Local secret matches plist + `SAFESIGHT_API_BASE_URL` set | Scan completes |
| Hosted URL + wrong/missing secret | Scan failed drawer, no credit charged |

[← Back to README](../README.md)
