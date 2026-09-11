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
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue?style=for-the-badge" alt="GPL-3.0" />
</p>

---

## Demo



https://github.com/user-attachments/assets/f64f8f53-fefa-4e8b-b71f-d148672f56f8



---

## AI proof

Live hosted scans against `https://safesight.noahwhiteson.com` — **3/3 passed** on `gemini-3.8-flash` (~3s each). Share cards use the same export chrome as the iOS app (`ScanShareExporter`).

| Scene | Latency | House Score | Hazards |
|-------|---------|-------------|---------|
| Kitchen | 3.1s | 68 | 3 |
| Hallway | 3.8s | 82 | 2 |
| Kitchen (stock) | 3.0s | 85 | 2 |

<p align="center">
  <img src="docs/benchmark/share-kitchen.jpg" alt="Kitchen share card — House Score 68" width="46%" />
  &nbsp;
  <img src="docs/benchmark/share-hallway.jpg" alt="Hallway share card — House Score 82" width="46%" />
</p>
<p align="center">
  <sub>Kitchen · 68/100 &nbsp;·&nbsp; Hallway · 82/100</sub>
</p>

Full tables, raw JSON, and how to re-run: **[docs/benchmark](docs/benchmark/README.md)**

---

## Table of contents

1. [Setup / run](./docs/setup.md)
2. [What is Safesight?](./docs/what-is-safesight.md)
3. [The problem](./docs/the-problem.md)
4. [What the app does](./docs/what-the-app-does.md)
5. [How it works](./docs/how-it-works.md)
6. [What’s inside the experience](./docs/experience.md)
7. [Design principles](./docs/design-principles.md)
8. [Tech at a glance](./docs/tech.md)
9. [FAQ](./docs/faq.md)
10. [Shipaton Next Gen](./docs/shipaton-next-gen.md)
11. [Safesight in real rooms](./docs/real-scans.md)
12. [AI benchmark](./docs/benchmark/README.md)
13. [Terms of Service](./docs/terms-of-service.md)
14. [Privacy Policy](./docs/privacy-policy.md)
15. [Disclaimer & license](./docs/disclaimer-and-license.md)

---

**Safesight** turns one room photo into labeled hazards, a House Score, and a path to fix — built for [Shipaton 2026 Next Gen](docs/shipaton-next-gen.md) with RevenueCat Premium.

<p align="center">
  <sub>Built with SwiftUI · Gemini · RevenueCat · for Shipaton Next Gen</sub>
</p>
