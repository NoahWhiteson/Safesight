# AI benchmark

Live suite on **20 distinct room photos** (unique files — not crops of one scene).
Share cards are the exact iOS `ScanShareExporter` output.

This is a **detection-accuracy** benchmark against human labels in
[`ground-truth.json`](./ground-truth.json) — not “JSON came back OK.”

- **Ran:** `2026-09-11 02:36:29Z`
- **API:** `https://safesight.noahwhiteson.com`
- **Model:** `gemini-3.8-flash`
- **Schema smoke:** 20/20 HTTP 200 + valid structure
- **Accuracy gate:** **19/20** cases found every required hazard · micro **F1 95.5%** · mean IoU **34%** · loc@0.3 **50%**

## Detection accuracy

Labeled ground truth in [`ground-truth.json`](./ground-truth.json). A case **passes** only if every **required** hazard is matched (alias and/or focus+box) and House Score lands in the labeled band. Schema-valid junk no longer counts as a pass.

- **Required-hazard recall (micro):** 96.4% (27/28)
- **Precision (micro):** 94.6%
- **F1 (micro):** 95.5%
- **Mean IoU (matched + boxed):** 34.2%
- **Localization @ IoU≥0.3:** 49.6%
- **Severity agreement (matched):** 100.0%
- **Score band hits:** 20/20
- **Cases with all required hazards found:** 19/20

| # | Scene | Recall | Precision | F1 | IoU | Loc@0.3 | Sev | Score | Gate |
|---|-------|--------|-----------|----|-----|---------|-----|-------|------|
| 1 | ✅ Kitchen (user) | 100% | 75% | 86% | 35% | 67% | 100% | 68 | pass |
| 2 | ❌ Living / hallway | 50% | 100% | 67% | 44% | 67% | 100% | 82 | miss |
| 3 | ✅ Kitchen (stock) | 100% | 50% | 67% | 22% | 0% | 100% | 88 | pass |
| 4 | ✅ Bathroom | 100% | 100% | 100% | 53% | 100% | 100% | 78 | pass |
| 5 | ✅ Bedroom | 100% | 100% | 100% | 41% | 67% | 100% | 86 | pass |
| 6 | ✅ Living (sofa) | 100% | 100% | 100% | 44% | 67% | 100% | 78 | pass |
| 7 | ✅ Kitchen (white) | 100% | 100% | 100% | 42% | 100% | 100% | 82 | pass |
| 8 | ✅ Bedroom (boho) | 100% | 100% | 100% | 12% | 0% | 100% | 82 | pass |
| 9 | ✅ Laundry room | 100% | 100% | 100% | 43% | 100% | 100% | 88 | pass |
| 10 | ✅ Living (windows) | 100% | 100% | 100% | 34% | 50% | 100% | 88 | pass |
| 11 | ✅ Dining room | 100% | 100% | 100% | 20% | 0% | 100% | 78 | pass |
| 12 | ✅ Living (modern) | 100% | 100% | 100% | 30% | 25% | 100% | 78 | pass |
| 13 | ✅ Living + stairs | 100% | 100% | 100% | 44% | 67% | 100% | 62 | pass |
| 14 | ✅ Kitchen (cooking) | 100% | 100% | 100% | 39% | 67% | 100% | 68 | pass |
| 15 | ✅ Home office | 100% | 100% | 100% | 10% | 0% | 100% | 88 | pass |
| 16 | ✅ Bathroom (modern) | 100% | 67% | 80% | 44% | 100% | 100% | 82 | pass |
| 17 | ✅ Closet / wardrobe | 100% | 100% | 100% | 45% | 50% | 100% | 62 | pass |
| 18 | ✅ Kitchen (island) | 100% | 100% | 100% | 25% | 0% | 100% | 86 | pass |
| 19 | ✅ Open plan + patio | 100% | 100% | 100% | 36% | 67% | 100% | 88 | pass |
| 20 | ✅ Garage | 100% | 100% | 100% | 19% | 0% | 100% | 68 | pass |

### Missed required hazards

- **Living / hallway** — `leaning-mirror` (Tip-over risks; aliases: mirror, leaning)

## Safesight in real rooms

Real scans from the app — boxes on the photo, confidence on each label, House Score on the share card.

<p align="center">
  <img src="../assets/share-examples/desk.jpg" alt="Desk scan — House Score 88" width="46%" />
  &nbsp;
  <img src="../assets/share-examples/bathroom.jpg" alt="Bathroom scan — House Score 82" width="46%" />
</p>
<p align="center">
  <sub>Desk · 88/100 &nbsp;·&nbsp; Bathroom · 82/100</sub>
</p>

<p align="center">
  <img src="../assets/share-examples/hallway.jpg" alt="Hallway scan — House Score 68" width="46%" />
  &nbsp;
  <img src="../assets/share-examples/kitchen.jpg" alt="Kitchen scan — House Score 78" width="46%" />
</p>
<p align="center">
  <sub>Hallway · 68/100 &nbsp;·&nbsp; Kitchen · 78/100</sub>
</p>

## Cases (schema smoke)

HTTP/latency/structure only — see **Detection accuracy** above for labeled scoring.

| # | Scene | HTTP | Latency | Score | Hazards | Schema |
|---|-------|------|---------|-------|---------|--------|
| 1 | ✅ Kitchen (user) | 200 | 5.39s | 68 | 4 | ok |
| 2 | ✅ Living / hallway | 200 | 4.11s | 82 | 3 | ok |
| 3 | ✅ Kitchen (stock) | 200 | 8.59s | 88 | 2 | ok |
| 4 | ✅ Bathroom | 200 | 3.95s | 78 | 3 | ok |
| 5 | ✅ Bedroom | 200 | 3.51s | 86 | 3 | ok |
| 6 | ✅ Living (sofa) | 200 | 3.34s | 78 | 3 | ok |
| 7 | ✅ Kitchen (white) | 200 | 2.84s | 82 | 2 | ok |
| 8 | ✅ Bedroom (boho) | 200 | 2.98s | 82 | 2 | ok |
| 9 | ✅ Laundry room | 200 | 3.75s | 88 | 2 | ok |
| 10 | ✅ Living (windows) | 200 | 2.71s | 88 | 2 | ok |
| 11 | ✅ Dining room | 200 | 3.7s | 78 | 4 | ok |
| 12 | ✅ Living (modern) | 200 | 3.49s | 78 | 4 | ok |
| 13 | ✅ Living + stairs | 200 | 3.4s | 62 | 3 | ok |
| 14 | ✅ Kitchen (cooking) | 200 | 3.16s | 68 | 3 | ok |
| 15 | ✅ Home office | 200 | 2.64s | 88 | 2 | ok |
| 16 | ✅ Bathroom (modern) | 200 | 3.3s | 82 | 3 | ok |
| 17 | ✅ Closet / wardrobe | 200 | 3.87s | 62 | 4 | ok |
| 18 | ✅ Kitchen (island) | 200 | 2.47s | 86 | 1 | ok |
| 19 | ✅ Open plan + patio | 200 | 3.34s | 88 | 3 | ok |
| 20 | ✅ Garage | 200 | 3.72s | 68 | 3 | ok |

## Share cards (native `ScanShareExporter`)

### Kitchen (user) — 68/100

> Exposed knife on the island edge and a runner rug without non-slip backing create injury and trip risks.

<p align="center">
  <img src="share-01-kitchen-user.jpg" alt="Kitchen (user) Safesight share card" width="52%" />
</p>

| Hazard | Severity | Confidence | Focus |
|--------|----------|------------|-------|
| Unsecured Chef Knife on Counter | High | 98% | Sharp objects |
| Curled Kitchen Runner Rug | Medium | 88% | Trip hazards |
| Towel Hanging on Oven Handle | Low | 82% | Fire |
| Combustible Paper Near Sink and Cook | Low | 74% | Kitchen hazards |

### Living / hallway — 82/100

> Living room is well kept, but unanchored tall items present tip-over and path hazards.

<p align="center">
  <img src="share-02-living-hallway.jpg" alt="Living / hallway Safesight share card" width="52%" />
</p>

| Hazard | Severity | Confidence | Focus |
|--------|----------|------------|-------|
| Tall Plant Tip-Over Risk | Medium | 84% | Tip-over risks |
| Unanchored Credenza | Medium | 76% | Tip-over risks |
| Area Rug Edge Trip Hazard | Low | 68% | Trip hazards |

### Kitchen (stock) — 88/100

> Clean kitchen space with minor risks from heavy cookware placed near the island edge.

<p align="center">
  <img src="share-03-kitchen-stock.jpg" alt="Kitchen (stock) Safesight share card" width="52%" />
</p>

| Hazard | Severity | Confidence | Focus |
|--------|----------|------------|-------|
| Heavy pot lid near edge | Low | 85% | Kitchen hazards |
| Unsecured Dutch oven placement | Low | 80% | Kitchen hazards |

### Bathroom — 78/100

> Bathroom is generally tidy, but a stool and accessible cabinet pose minor safety risks.

<p align="center">
  <img src="share-04-bathroom.jpg" alt="Bathroom Safesight share card" width="52%" />
</p>

| Hazard | Severity | Confidence | Focus |
|--------|----------|------------|-------|
| Loose Step Stool | Medium | 85% | Child proofing |
| Floor Obstruction | Low | 80% | Trip hazards |
| Accessible Wall Cabinet | Medium | 75% | Child proofing |

### Bedroom — 86/100

> The bedroom is well kept, but exposed hot bulbs and top-heavy accents pose minor hazards.

<p align="center">
  <img src="share-05-bedroom.jpg" alt="Bedroom Safesight share card" width="52%" />
</p>

| Hazard | Severity | Confidence | Focus |
|--------|----------|------------|-------|
| Low Exposed Light Fixture Bulbs | Medium | 84% | Fire |
| Unanchored Nightstand Table Lamp | Low | 72% | Tip-over risks |
| Floor-Length Drapes Near Window | Low | 65% | Windows & falls |

### Living (sofa) — 78/100

> Tall floor lamp and slender accent table present minor tip-over risks in the living space.

<p align="center">
  <img src="share-06-living-sofa.jpg" alt="Living (sofa) Safesight share card" width="52%" />
</p>

| Hazard | Severity | Confidence | Focus |
|--------|----------|------------|-------|
| Slender Floor Lamp Tip Risk | Medium | 85% | Tip-over risks |
| Fragile Tall Glass Vase | Medium | 88% | Pet hazards |
| Loose Lamp Power Cord | Low | 72% | Trip hazards |

### Kitchen (white) — 82/100

> Overall tidy kitchen with minor fire hazard and floor rug tripping risk.

<p align="center">
  <img src="share-07-kitchen-white.jpg" alt="Kitchen (white) Safesight share card" width="52%" />
</p>

| Hazard | Severity | Confidence | Focus |
|--------|----------|------------|-------|
| Towel hung on oven door handle | Medium | 88% | Fire |
| Unsecured fringed floor rug | Medium | 92% | Trip hazards |

### Bedroom (boho) — 82/100

> Bedroom shows potential candle fire risk near foliage and an exposed bedside cord.

<p align="center">
  <img src="share-08-bedroom-boho.jpg" alt="Bedroom (boho) Safesight share card" width="52%" />
</p>

| Hazard | Severity | Confidence | Focus |
|--------|----------|------------|-------|
| Candle Near Hanging Plants | Medium | 85% | Fire |
| Unsecured Sconce Lamp Cord | Low | 78% | Electric |

### Laundry room — 88/100

> Chemical detergent handling presents spill, contact, and ingestion risks if left unsecured.

<p align="center">
  <img src="share-09-laundry.jpg" alt="Laundry room Safesight share card" width="52%" />
</p>

| Hazard | Severity | Confidence | Focus |
|--------|----------|------------|-------|
| Open Detergent Container | Medium | 92% | Chemical storage |
| Dispenser Spill Risk | Low | 75% | Chemical storage |

### Living (windows) — 88/100

> Dining space is clean with minimal hazards, though curtain drape length presents a slight trip risk.

<p align="center">
  <img src="share-10-living-windows.jpg" alt="Living (windows) Safesight share card" width="52%" />
</p>

| Hazard | Severity | Confidence | Focus |
|--------|----------|------------|-------|
| Puddling Curtain Fabric | Low | 76% | Trip hazards |
| Floor-to-Ceiling Glass Impact | Low | 70% | Windows & falls |

### Dining room — 78/100

> Dining space presents minor breakable glass and potential sharp edge risks for children.

<p align="center">
  <img src="share-11-dining.jpg" alt="Dining room Safesight share card" width="52%" />
</p>

| Hazard | Severity | Confidence | Focus |
|--------|----------|------------|-------|
| Accessible Glass Decanters | Medium | 88% | Child proofing |
| Fragile Tall Glassware | Low | 82% | Sharp objects |
| Sharp Table Edges | Low | 76% | Child proofing |
| Narrow Base Tall Pedestal Vase | Low | 70% | Tip-over risks |

### Living (modern) — 78/100

> Living space is tidy but has minor tip-over, toxic plant, and ottoman trip hazards.

<p align="center">
  <img src="share-12-living-modern.jpg" alt="Living (modern) Safesight share card" width="52%" />
</p>

| Hazard | Severity | Confidence | Focus |
|--------|----------|------------|-------|
| Toxic Snake Plant to Pets | Medium | 88% | Pet hazards |
| Tall Fragile Decor Tip-Over | Low | 75% | Tip-over risks |
| Floor Poufs In Walkway | Low | 72% | Trip hazards |
| Arc Floor Lamp Tip-Over | Medium | 70% | Tip-over risks |

### Living + stairs — 62/100

> Floating stairs lack handrails and the transparent balustrade creates fall and collision risks.

<p align="center">
  <img src="share-13-living-stairs.jpg" alt="Living + stairs Safesight share card" width="52%" />
</p>

| Hazard | Severity | Confidence | Focus |
|--------|----------|------------|-------|
| Staircase Missing Handrail | High | 94% | Stairs & falls |
| Low-Visibility Glass Balustrade | Medium | 85% | Child proofing |
| Raised Texture Rug Edge | Low | 78% | Trip hazards |

### Kitchen (cooking) — 68/100

> Stove-edge cookpot placement and reach-across scraping create burn and scald risks.

<p align="center">
  <img src="share-14-kitchen-cooking.jpg" alt="Kitchen (cooking) Safesight share card" width="52%" />
</p>

| Hazard | Severity | Confidence | Focus |
|--------|----------|------------|-------|
| Large pot at cooktop edge | High | 88% | Kitchen hazards |
| Reaching over open hot pot | Medium | 82% | Kitchen hazards |
| Accessible front range dials | Medium | 75% | Child proofing |

### Home office — 88/100

> Workspace is well-organized with minimal hazards, noting an exposed electrical cord near baseboard.

<p align="center">
  <img src="share-15-home-office.jpg" alt="Home office Safesight share card" width="52%" />
</p>

| Hazard | Severity | Confidence | Focus |
|--------|----------|------------|-------|
| Trailing Floor Cable | Low | 85% | Trip hazards |
| Unsecured Wall Cord | Low | 80% | Electric |

### Bathroom (modern) — 82/100

> Bathroom is clean and modern, but loose mat and sharp vanity edges pose slip and impact hazards.

<p align="center">
  <img src="share-16-bathroom-modern.jpg" alt="Bathroom (modern) Safesight share card" width="52%" />
</p>

| Hazard | Severity | Confidence | Focus |
|--------|----------|------------|-------|
| Unsecured bath mat | Medium | 88% | Trip hazards |
| Sharp floating vanity corners | Low | 82% | Child proofing |
| Accessible toilet lid | Low | 78% | Child proofing |

### Closet / wardrobe — 62/100

> Tall unanchored furniture and exposed low-level wall sockets present tip-over and child safety risks.

<p align="center">
  <img src="share-17-closet.jpg" alt="Closet / wardrobe Safesight share card" width="52%" />
</p>

| Hazard | Severity | Confidence | Focus |
|--------|----------|------------|-------|
| Unanchored Tall Wardrobe | High | 92% | Tip-over risks |
| Exposed Low Electrical Outlet | Medium | 88% | Child proofing |
| Accessible Drawers Create Ladder | Medium | 80% | Child proofing |
| Low Plug Near High-Traffic Zone | Low | 76% | Electric |

### Kitchen (island) — 86/100

> Overall kitchen is tidy, but loose floor matting poses a tripping risk.

<p align="center">
  <img src="share-18-kitchen-island.jpg" alt="Kitchen (island) Safesight share card" width="52%" />
</p>

| Hazard | Severity | Confidence | Focus |
|--------|----------|------------|-------|
| Loose runner rug on floor | Medium | 88% | Trip hazards |

### Open plan + patio — 88/100

> Living area is tidy with minor tip-over and impact risks from low accent tables.

<p align="center">
  <img src="share-19-patio-door.jpg" alt="Open plan + patio Safesight share card" width="52%" />
</p>

| Hazard | Severity | Confidence | Focus |
|--------|----------|------------|-------|
| Unstable pedestal side table | Low | 78% | Child proofing |
| Rigid table edge at child height | Low | 72% | Child proofing |
| Glass sliding door collision risk | Low | 68% | Windows & falls |

### Garage — 68/100

> Multiple uncontained chemicals and automotive fluids stored openly in work zone.

<p align="center">
  <img src="share-20-garage.jpg" alt="Garage Safesight share card" width="52%" />
</p>

| Hazard | Severity | Confidence | Focus |
|--------|----------|------------|-------|
| Open Shelf Flammable Liquids | Medium | 88% | Fire |
| Unsecured Chemical Containers | Medium | 85% | Chemical storage |
| Floor Fluid Jug Obstruction | Low | 75% | Trip hazards |

[← Back to README](../README.md)
