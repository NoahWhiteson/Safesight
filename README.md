<p align="center">
  <img src="docs/assets/safesight-banner.png" alt="Safesight" width="100%" />
</p>

<p align="center">
  <strong>Point your camera at a room. Safesight finds visible risks and tells you what to fix.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-SwiftUI-000000?style=for-the-badge&logo=apple&logoColor=white" alt="iOS SwiftUI" />
  <img src="https://img.shields.io/badge/Gemini-Vision-4285F4?style=for-the-badge&logo=googlegemini&logoColor=white" alt="Gemini" />
  <img src="https://img.shields.io/badge/RevenueCat-Subscriptions-F25A3C?style=for-the-badge" alt="RevenueCat" />
  <img src="https://img.shields.io/badge/Shipaton-Next%20Gen-0A84FF?style=for-the-badge" alt="Shipaton Next Gen" />
</p>

---

## What it is

**Safesight** is an iOS home-safety app. You photograph a room; AI finds **visible** hazards, scores the space, and helps you fix what matters — built for **Shipaton 2026 Next Gen**.

It’s for real rooms: cords, clutter, tip-overs, blocked exits, kid risks — not invisible stuff like gas or radon.

---

## What it does

- **Scan a room** — camera → analysis → House Score + summary  
- **See hazards on the photo** — labeled boxes on the exact spots  
- **Nested groups** — stacked findings merge; tap to reveal what’s inside  
- **Fix flow** — short steps, mark Fixed / Dismissed / Reopen  
- **House memory** — open issues stay on the Hazards tab across scans  
- **Look hardness** — control how aggressive the scan digs  
- **Focus areas** — fire, water, electric, child-proofing, trips, exits, and more  
- **Shop picks** — products matched to what was found  
- **Premium** — unlimited scans + extra focus areas (RevenueCat)

---

## How it works

```text
Photo  →  Gemini vision  →  hazards + boxes  →  fix / shop / Premium
```

1. You pick **focus areas** and snap a room.  
2. **Gemini** looks at the image and returns structured findings (title, severity, fix steps, bounding box).  
3. Safesight draws those boxes on the photo, tracks open vs fixed issues, and unlocks deeper use through **RevenueCat** (`safesight_pro`).

AI suggestions only — not a professional inspection.

---

## License

See [`LICENSE`](LICENSE) (GPL-3.0).

---

<p align="center">
  <sub>SwiftUI · Gemini · RevenueCat · Shipaton Next Gen</sub>
</p>
