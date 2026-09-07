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

## What is Safesight?

**Safesight** is an iOS app that turns a single room photo into a clear safety readout.

Instead of a generic checklist, you point the camera at a real space — bedroom, hallway, kitchen, dorm — and Safesight highlights **what’s actually in the frame**: tip-over furniture, trip paths, blocked exits, messy cords, outlet risks, and other **visible** issues. Each finding gets a label on the photo, a short explanation, and concrete next steps.

It’s built for people who care about the rooms they live in or watch over — teens, siblings, babysitting, family homes — without pretending to be a licensed inspector.

Safesight is a **Shipaton 2026 Next Gen** project: a student-built app with a real product loop and **RevenueCat**-powered Premium.

---

## Safesight in real rooms

Real scans from the app — boxes on the photo, confidence on each label, House Score on the share card.

<p align="center">
  <img src="docs/assets/share-examples/desk.jpg" alt="Desk scan — House Score 88" width="46%" />
  &nbsp;
  <img src="docs/assets/share-examples/bathroom.jpg" alt="Bathroom scan — House Score 82" width="46%" />
</p>
<p align="center">
  <sub>Desk · 88/100 &nbsp;·&nbsp; Bathroom · 82/100</sub>
</p>

<p align="center">
  <img src="docs/assets/share-examples/hallway.jpg" alt="Hallway scan — House Score 68" width="46%" />
  &nbsp;
  <img src="docs/assets/share-examples/kitchen.jpg" alt="Kitchen scan — House Score 78" width="46%" />
</p>
<p align="center">
  <sub>Hallway · 68/100 &nbsp;·&nbsp; Kitchen · 78/100</sub>
</p>

---

## The problem

Home safety advice is usually:

- long PDFs nobody finishes  
- generic tips that don’t match *your* room  
- anxiety without a clear “what do I do next?”

What’s missing is something **visual and immediate**: see the hazard where it is, understand why it matters, then fix it or dismiss it.

That’s the gap Safesight fills.

---

## What the app does

### Scan a room
Open **Scan**, capture a photo **or upload one from your library**, and Safesight analyzes the image against your chosen **focus areas** (fire, water leaks, electric, child-proofing, trip hazards, blocked exits, and more). You get:

- a **House Score** for that frame  
- a short **AI summary**  
- a list of hazards with severity  

You can **share** any scan as a branded PNG — annotated photo with boxes and titles, the Safesight logo, and the score — through Messages, Instagram, Mail, or anything else the system share sheet supports.

### See hazards on the photo
Findings aren’t buried in text. Safesight draws **bounding boxes** on the image and fuses **labels** to the outline so you can see exactly where each issue is. Each hazard label includes an **accuracy metre** — a percentage showing how sure the model is that the named hazard is actually there.

When detections stack or nest inside each other, they collapse into **one group box**. Tap to expand and inspect the hazards inside — then collapse again when you’re done.

### Fix, track, and remember
Each hazard can be:

- **Fixed** — you handled it  
- **Dismissed** — not relevant  
- **Reopened** — if it comes back  

Open issues live on the **Hazards** tab across scans, so the house has memory — not just a one-off screenshot.

### Tune how hard it looks
**Look hardness** controls how aggressive analysis is: more conservative for obvious risks only, or more aggressive to surface borderline / preventive issues. That also affects how many hazards a scan can return.

### Act on what you find
Safesight suggests **product picks** matched to the hazards it found, so “I see the problem” can turn into “I can buy the fix.”

### Premium
Free use covers the core experience with limits. **Premium** (via RevenueCat) unlocks unlimited scanning and premium focus areas — the monetization layer Shipaton cares about, wired as a real subscription entitlement (`safesight_pro`).

---

## How it works

At a high level:

```text
  Focus areas + photo
          │
          ▼
   Gemini vision model
   (structured JSON)
          │
          ▼
  Hazards · boxes · confidence · score · summary · products
          │
          ▼
  Overlays on photo · lifecycle · Home / Hazards · Premium
```

### 1. You set intent
Onboarding captures who you are, what kind of home you’re in, and which **focus areas** matter. Those choices gate what the model is allowed to report — so a child-proofing scan doesn’t invent unrelated noise.

### 2. Vision in, structure out
The room photo is sent to the **Safesight API**, which calls **Gemini** with a strict schema. The model returns hazards with titles, details, severity, fix steps, a **normalized bounding box** (`0…1` coordinates on the image), and a **confidence** score (0–100). The app maps those fractions onto the displayed photo, draws the overlays, and shows the confidence as a percentage on each label tab.

### 3. Product layer on top
Boxes get collision-aware labels. Nested detections become expandable groups. History stores scans on-device. The Hazards tab aggregates what’s still open. RevenueCat checks entitlement for Premium unlocks.

No separate object-detector pipeline — the boxes come from the same vision pass that names the hazards.

---

## What’s inside the experience

| Surface | Role |
|---------|------|
| **Home** | Score, summary, recommendations, recent activity |
| **Scan** | Camera, analysis, annotated photo, results drawer |
| **Hazards** | House-wide open issues |
| **Premium** | RevenueCat paywall / upgrade |
| **You** | Profile, focus areas, look hardness, account-style controls |

Supporting pieces: onboarding, scan gallery (star / auto-purge), haptic feedback, and a thinking overlay while analysis runs.

---

## Design principles

- **Visible only** — if the camera can’t see it, Safesight shouldn’t invent it  
- **Show, don’t just tell** — boxes on the photo beat walls of text  
- **Actionable** — every finding should push toward fix, dismiss, or shop  
- **Honest AI** — assistant for home awareness, not a certification  
- **Monetization with a job** — Premium expands capacity; it isn’t a fake lock on empty screens  

---

## Tech at a glance

| Layer | Choice |
|-------|--------|
| UI | SwiftUI (+ UIKit tab host) |
| API | Safesight server (`server/`) — Gemini key stays off-device |
| Vision | Google Gemini via `POST /v1/analyze` |
| Subscriptions | RevenueCat (`monthly` / `yearly` → `safesight_pro`) |
| Commerce hints | Amazon-style search picks tied to hazards |
| Persistence | On-device scan images + history index |

---

## Shipaton Next Gen

Safesight targets the **Next Gen Award**: student builders (13+) judged on idea, working progress, thoughtful **RevenueCat** use, and craft — via demo video and open-source code rather than a store listing.

The product bet is simple: **one photo → clear hazards → a path to fix** — with Premium as a real unlock, not an afterthought.

---

## Disclaimer

Safesight is an AI assistant for **visible** home risks. It is not a professional inspection, insurance assessment, or emergency service. Use judgment for anything that could cause injury or fire.

---

## License

This project is licensed under the **GNU General Public License v3.0**.  
See [`LICENSE`](LICENSE) for the full terms.

---

<p align="center">
  <sub>Built with SwiftUI · Gemini · RevenueCat · for Shipaton Next Gen</sub>
</p>
