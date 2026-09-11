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

Live hosted suite against `https://safesight.noahwhiteson.com` — **20/20 passed** on `gemini-3.8-flash` across **20 distinct room photos** (unique files, not crops of one scene). Share cards are the exact iOS `ScanShareExporter` output.

| | |
|--|--|
| **Passed** | 20 / 20 |
| **Distinct sources** | 20 unique photos |
| **Scenes** | kitchen · living · bathroom · bedroom · dining · office · closet · garage · laundry · stairs |
| **Latency** | ~2.5–8.6s |

<p align="center">
  <img src="docs/benchmark/share-01-kitchen-user.jpg" alt="Kitchen share card" width="31%" />
  &nbsp;
  <img src="docs/benchmark/share-04-bathroom.jpg" alt="Bathroom share card" width="31%" />
  &nbsp;
  <img src="docs/benchmark/share-11-dining.jpg" alt="Dining share card" width="31%" />
</p>

Full 20-case table, raw JSON, and native share cards: **[docs/benchmark](docs/benchmark/README.md)**

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
