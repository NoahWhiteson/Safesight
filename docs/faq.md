# FAQ

Two tracks: **User FAQ** for people using the app, **Judge FAQ** for Shipaton reviewers who want the hard accuracy / scoring answers.

---

## User FAQ

### What is Safesight?

An iOS app that turns a room photo into labeled **visible** hazards, a short summary, and a **House Score** — then helps you fix, dismiss, or track what you found.

### Is this a professional home inspection?

No. Safesight is an AI assistant for risks you can **see in a photo**. It is not a licensed inspection, insurance assessment, or emergency service. Use judgment for anything that could cause injury or fire.

### Do I need Premium to try it?

No. Free includes **2 scans** and core on-scan results (score, hazards, boxes). **Premium** (RevenueCat) unlocks unlimited scanning, premium focus areas, and the full Home dashboard (AI summary & product picks).

### Does a failed scan use a credit?

No. Free-scan credits are only charged after a **successful** analysis.

### Why didn’t it find something I know is dangerous?

Usually because it isn’t clearly visible in the frame, it’s outside your selected **focus areas**, lighting/angle hid it, or the model treated it as ambiguous. Try a closer shot, better light, or different focus areas. Re-scan after you change the room.

### Why did it flag something that isn’t a real hazard?

Vision models can over-read clutter, shadows, or “looks risky” shapes. Dismiss findings that don’t apply. Adjust **look hardness** if scans feel too aggressive.

### What does the percentage on a hazard label mean?

That’s the model’s **self-reported confidence** (0–100) that the named hazard is real and correctly identified in the photo — not a measured lab accuracy rate. Treat high % as “the model is sure,” not “ground-truth verified.”

### Are my photos uploaded forever?

Scan images and history live **on-device** in the app’s storage. Analysis sends the photo to the Safesight API for that request so Gemini can run. See [How it works](./how-it-works.md) and [Setup / run](./setup.md).

### Can I share a scan?

Yes — share exports a branded PNG (annotated photo, logo, House Score) through the system share sheet.

### Where do product suggestions come from?

Safesight suggests fix-oriented picks matched to the hazards it found (catalog / search-style recommendations). They’re suggestions, not endorsements.

---

## Judge FAQ

Answers tailored for Shipaton Next Gen review: what we claim, what we don’t, and how the system behaves under scrutiny.

### Can I clone the repo and run a scan immediately against production?

**No — and that’s intentional.** The hosted API (`https://safesight.noahwhiteson.com`) requires a shared `SAFESIGHT_API_SECRET` that is **not** in git. Without it (or a matching local setup), analyze fails and you see the scan-failed drawer.

**How to run a real scan yourself:**

1. Preferred: follow [Setup / run §2](./setup.md) — local `server/` with **your** Gemini API key and **your own** secret in both `.env` and `SafesightAPISecrets.plist`, plus `SAFESIGHT_API_BASE_URL` → `http://127.0.0.1:8787`. No production secret needed.  
2. Optional: request a short-lived hosted secret via Devpost / author contact.  
3. Next Gen judging still centers on the **demo video + source**; the repo must be runnable with instructions, not necessarily with free production Gemini.

### How often does it miss genuine hazards?

We publish a labeled detection benchmark in [docs/benchmark](./benchmark/README.md): required-hazard recall/precision/F1, box IoU, and per-case misses against [`ground-truth.json`](./benchmark/ground-truth.json). It is **not** a third-party audit or a certified miss rate for every home — boxes stay directional and Gemini is stochastic — but it is more than “structured JSON came back.”

In practice, misses cluster around:

- hazards **not visible** (behind furniture, out of frame, micro defects)
- issues outside selected **focus areas** (by design)
- ambiguous scenes where the model stays conservative
- hard lighting, motion blur, extreme wide shots

Mitigations in product: focus-area gating, look hardness / max hazards, re-scan, and user fix/dismiss so the house has memory beyond one frame.

**Honest bar for judges:** treat Safesight as a **visible-risk assistant**, not a detector with quantified recall.

### How often does it invent hazards?

Again — **no calibrated false-positive rate** published. Invented or stretched findings do happen (clutter → trip hazard, reflections → moisture, etc.).

We reduce invention by:

- prompting for **visible-only** findings
- gating output to selected focus areas
- structured JSON schema on the API
- letting users **dismiss** bad calls without pretending they’re “ground truth”

If you re-scan the same messy room twice, you may still see occasional extras. Prefer judging whether inventions are **plausible and dismissible**, not zero.

### Are the bounding boxes actually accurate?

**Mostly directional, not pixel-perfect.** Boxes come from the **same Gemini vision pass** that names the hazard — there is no separate object-detector / SAM pipeline.

Pipeline:

1. Model returns normalized boxes (`0…1` on the image)  
2. Server + client **sanitize / coerce** formats and tighten oversized frames  
3. UI maps boxes onto the photo with collision-aware labels; nested hits can **group**

So a box should usually land on the right region (cord, outlet, doorway). Expect drift on thin objects, soft edges, and crowded scenes. We invested in geometry hardening because early Gemini boxes were unreliable — see server `mapResponse` + client `withSanitizedBoxes()`.

### Does the displayed “confidence” reflect measured accuracy or only the model’s self-reported confidence?

**Self-reported only** on the label chip.

The UI percentage is the model’s `confidence` field (0–100), prompted as “how sure you are this hazard is real and correctly identified.” Separately, the repo benchmark reports **precision / recall / F1 / IoU** against human labels — that is *not* what the on-hazard % shows.

Reading tip: use the chip as a **relative** signal within a scan (clear cord tip-over often high; ambiguous clutter lower), not as a scientific accuracy metre.

### How stable are results when the same room is scanned twice?

**Not bit-stable.** Same room, similar photo → usually similar themes and score band; exact hazard titles, counts, boxes, and confidence can shift because Gemini is stochastic and framing/exposure change.

Expect:

- same obvious hazards to recur often  
- borderline items to flicker in/out  
- House Score to move within a band more often than jump wildly  

That’s acceptable for a guidance loop (scan → fix → re-scan). It would be a problem if we marketed “certified reproducible inspection.”

### Can the House Score be defended?

**Yes as a product score — not as a regulatory or actuarial rating.**

What it is:

- A **0–100 score for this frame** vs selected focus areas, proposed by the model in the same structured response as the hazards  
- Shown as House Score on Home / results / share cards  
- After users fix or dismiss hazards, the app can **recompute** score from remaining open severities (severity-weighted deduction), so the number tracks lifecycle — not only the first model dump  

What it is not:

- An insurer score, code compliance grade, or cross-home ranking  
- A claim that two homes with “82” are equally safe  

**Defense for judges:** the score is a **readable summary of visible, in-scope findings** so the UI isn’t a wall of text — defended by transparency (what it measures) and lifecycle (it updates when hazards close), not by claiming measurement science.

### What should we evaluate for Next Gen?

Per [Shipaton Next Gen](./shipaton-next-gen.md) / Devpost: idea, working progress, RevenueCat use, craft — via **demo video + this repo** (including [Setup / run](./setup.md)). Prefer judging the **scan → boxes → act → Premium** loop, and use [docs/benchmark](./benchmark/README.md) if you want labeled detection numbers (recall/precision/IoU) rather than marketing “20/20 structured OK.”

[← Back to README](../README.md)
