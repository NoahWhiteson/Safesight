# How it works

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

## 1. You set intent

Onboarding captures who you are, what kind of home you’re in, and which **focus areas** matter. Those choices gate what the model is allowed to report — so a child-proofing scan doesn’t invent unrelated noise.

## 2. Vision in, structure out

The room photo is sent to the **Safesight API**, which calls **Gemini** with a strict schema. The model returns hazards with titles, details, severity, fix steps, a **normalized bounding box** (`0…1` coordinates on the image), and a **confidence** score (0–100). The app maps those fractions onto the displayed photo, draws the overlays, and shows the confidence as a percentage on each label tab.

## 3. Product layer on top

Boxes get collision-aware labels. Nested detections become expandable groups. History stores scans on-device. The Hazards tab aggregates what’s still open. RevenueCat checks entitlement for Premium unlocks.

No separate object-detector pipeline — the boxes come from the same vision pass that names the hazards.

[← Back to README](../README.md)
