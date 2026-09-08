# Setup / run

Shipaton Next Gen judges evaluate from the **demo video + this repo**. These steps are enough to open Safesight in Xcode and run scans.

## Requirements

- macOS with **Xcode** (project deployment target: **iOS 26.5**)
- An iPhone Simulator or a physical device (camera scans need a device; photo upload works on Simulator)
- Optional: Node.js 18+ if you want to run the API locally instead of the hosted server

## 1. Clone and open

```bash
git clone https://github.com/NoahWhiteson/Safesight.git
cd Safesight
open Safesight.xcodeproj
```

## 2. API access (required for scans)

The app does **not** call Gemini directly. It hits the Safesight API (`POST /v1/analyze`) with a shared secret.

By default the app uses the hosted API:

`https://safesight.noahwhiteson.com`

1. Copy the example secrets file:

```bash
cp Safesight/SafesightAPISecrets.example.plist Safesight/SafesightAPISecrets.plist
```

2. Open `SafesightAPISecrets.plist` and set `API_SECRET` to the same value as the server’s `SAFESIGHT_API_SECRET`.

`SafesightAPISecrets.plist` is gitignored — never commit real secrets.

Without a matching secret, analysis fails and the scan-failed drawer appears (no free-scan credit is used).

### Option A — Hosted API (fastest)

Use the default base URL (no Info.plist change). You need a secret that matches the deployed server.

### Option B — Local API

```bash
cd server
cp .env.example .env
# Set GEMINI_API_KEY and SAFESIGHT_API_SECRET in .env
npm install
npm start
```

Server listens on `http://127.0.0.1:8787` by default. Point the app at it by adding to `Safesight/Info.plist`:

| Key | Type | Value |
|-----|------|--------|
| `SAFESIGHT_API_BASE_URL` | String | `http://127.0.0.1:8787` |

Put the **same** secret in `SafesightAPISecrets.plist`.

More detail: [`server/README.md`](../server/README.md) (also mirrored at [Safesight_API](https://github.com/NoahWhiteson/Safesight_API)).

## 3. Run the app

1. In Xcode, select the **Safesight** scheme and a Simulator or device  
2. Build & Run (`⌘R`)  
3. Complete onboarding → open **Scan** → take a photo or upload one  

RevenueCat is already wired with a **Test Store** API key in `RevenueCatConfig.swift` (`safesight_pro` entitlement, `monthly` / `yearly` products). Premium / paywall flows work in that test configuration without a paid Apple Developer account for Next Gen judging.

## 4. Permissions

- **Camera** — required for live capture (system prompt on first use)  
- **Photo library** — required only if you use upload  

## Quick check

| Check | Expected |
|-------|----------|
| `GET https://safesight.noahwhiteson.com/health` (or local `/health`) | OK / healthy response |
| Secrets plist present + matching server secret | Scan completes or shows results drawer |
| Missing / wrong secret | Scan failed drawer, no credit charged |

[← Back to README](../README.md)
