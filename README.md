<p align="center">
  <img src="docs/assets/safesight-banner.png" alt="Safesight" width="100%" />
</p>

<p align="center">
  <strong>Point your camera at a room. Safesight finds visible risks and tells you what to fix.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-17%2B-000000?style=for-the-badge&logo=apple&logoColor=white" alt="iOS" />
  <img src="https://img.shields.io/badge/SwiftUI-Native-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/Gemini-Vision-4285F4?style=for-the-badge&logo=googlegemini&logoColor=white" alt="Gemini" />
  <img src="https://img.shields.io/badge/RevenueCat-Subscriptions-F25A3C?style=for-the-badge" alt="RevenueCat" />
  <img src="https://img.shields.io/badge/Shipaton-Next%20Gen-0A84FF?style=for-the-badge" alt="Shipaton Next Gen" />
</p>

---

## Why Safesight

Most “home safety” advice is a PDF nobody reads. Safesight turns **one photo** into:

- a **House Score**
- **labeled hazard boxes** on the actual image
- short **fix steps**
- **shop picks** that match what was found
- a house-wide **open hazards** list you can mark Fixed / Dismissed

Built for **Shipaton 2026 — Next Gen** (students 13+) as a local iOS demo powered by **RevenueCat**.

---

## Features

| Area | What you get |
|------|----------------|
| **Scan** | Camera capture → Gemini vision analysis → results drawer |
| **Overlays** | Precise AI bounding boxes + tabs fused to the outline |
| **Nested groups** | Stacked detections merge into one box — tap to reveal insides |
| **Lifecycle** | Open → Fixed / Dismissed / Reopen across the whole house |
| **Look hardness** | Slider that controls how aggressive Gemini digs (2–8 hazards) |
| **Focus areas** | Fire, water, electric, child-proofing, trips, exits + premium extras |
| **Home** | Score, AI summary, recommended products, recent activity |
| **Gallery** | Past scans, star to keep, auto-purge unstarred after 60 days |
| **Premium** | Unlimited scans + premium focus areas via RevenueCat |

```text
┌─────────┐    ┌──────────┐    ┌─────────────┐    ┌──────────┐
│  Camera │ →  │  Gemini  │ →  │  Annotated  │ →  │  Fix +   │
│  photo  │    │  vision  │    │  photo +    │    │  shop    │
└─────────┘    └──────────┘    │  hazards    │    └──────────┘
                               └─────────────┘
```

---

## Stack

- **SwiftUI** + UIKit tab host
- **Gemini** multimodal (image → structured JSON hazards / boxes)
- **RevenueCat** (`safesight_pro` entitlement · `monthly` / `yearly`)
- **Amazon** search-style product picks (Bing thumbs)
- On-device history (JPEG + `UserDefaults` index)

---

## Project layout

```text
Safesight/
├── SafesightApp.swift          # App entry + RevenueCat configure
├── ContentView.swift           # Onboarding → dashboard gate
├── OnboardingFlow.swift        # Name · dwelling · focus areas
├── DashboardView.swift         # Home / Scan / You + tab chrome
├── HazardsTabView.swift        # House-wide open hazards
├── CameraScanView.swift        # AVFoundation capture
├── GeminiScanAnalyzer.swift    # Vision prompt + parse + retries
├── GeminiConfig.swift          # Model + endpoint (key from plist)
├── ScanResultsView.swift       # Overlays · drawer · gallery
├── ScanModels.swift            # DTOs · boxes · lifecycle
├── ScanHistoryStore.swift      # Persist / star / purge
├── AmazonProductService.swift  # Hazard → product matching
├── SubscriptionStore.swift     # RC entitlements · free limits
├── PaywallView.swift           # Custom RC paywall
└── Assets.xcassets/            # Logo · wordmark · illustrations
```

---

## Run it locally

### Requirements

- Xcode 16+
- iOS Simulator or a physical device (camera scans need a device)
- A Gemini API key
- RevenueCat Test Store key (already wired for sandbox)

### 1. Clone

```bash
git clone https://github.com/NoahWhiteson/Safesight.git
cd Safesight
open Safesight.xcodeproj
```

### 2. Add your Gemini key

Secrets are **gitignored**. Copy the example and drop your key in:

```bash
cp Safesight/GeminiSecrets.example.plist Safesight/GeminiSecrets.plist
```

Edit `Safesight/GeminiSecrets.plist`:

```xml
<key>API_KEY</key>
<string>YOUR_KEY_HERE</string>
```

> Never commit `GeminiSecrets.plist`. The example file is safe to share.

### 3. Build & run

Select the **Safesight** scheme → iPhone simulator or device → **Run**.

### 4. Try a scan

1. Finish onboarding (pick focus areas)
2. Open **Scan** → capture a room
3. Wait for analysis → pull the results drawer
4. Tap boxes / expand nested groups / mark Fixed
5. Hit **Premium** to exercise the RevenueCat paywall (sandbox)

---

## Monetization (RevenueCat)

| | Free | Premium (`safesight_pro`) |
|--|------|---------------------------|
| Scans | Limited | Unlimited |
| Focus areas | Core set | Full set |
| Products / extras | Gated where configured | Unlocked |

Products:

- `monthly`
- `yearly`

Entitlement: **`safesight_pro`**

Configured in `RevenueCatConfig.swift` via the RevenueCat SDK (`SubscriptionStore` + `PaywallView`).

---

## How hazard boxes work

Gemini returns each hazard with a normalized bounding box (`x`, `y`, `width`, `height` in **0…1**, top-left origin). Safesight:

1. Maps those fractions onto the displayed photo
2. Draws a tight outline on the hazard
3. Fuses a label tab to the rim (collision-aware)
4. Merges nested / stacked boxes into one group you can expand

No separate detector — boxes come from the vision model’s structured output.

---

## Shipaton Next Gen

Safesight is entered as a **Next Gen** project:

- Demo video + public open-source repo (no paid Apple developer account required)
- Active student builder track (ages 13+)
- RevenueCat powers the subscription story judges look for

---

## Disclaimer

Safesight is an **AI assistant for visible home risks**, not a certified inspection, insurance tool, or emergency service. Always use judgment for anything that could cause injury or fire.

---

## License

MIT — see [`LICENSE`](LICENSE).

---

<p align="center">
  <sub>Built with SwiftUI · Gemini · RevenueCat · for Shipaton Next Gen</sub>
</p>
