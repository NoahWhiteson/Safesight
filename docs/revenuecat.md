# RevenueCat

Safesight uses **RevenueCat** as the real Premium layer for Shipaton Next Gen — not a stub switch. Free users get a complete core loop; Premium expands capacity where the product actually hurts after the first couple of scans.

## Why RevenueCat here

Next Gen judges thoughtful monetization. The bet:

- Free proves the loop: scan → boxes → score → fix/dismiss  
- Premium unlocks **more of the same job** (scans, focus areas, Home insights) — not an empty tab  

RevenueCat sits between StoreKit and the UI so entitlement stays one source of truth (`safesight_pro`), including Test Store for demos without a paid Apple Developer account.

## Catalog

Configured in [`Safesight/RevenueCatConfig.swift`](../Safesight/RevenueCatConfig.swift):

| Piece | ID |
|-------|-----|
| Entitlement | `safesight_pro` |
| Monthly product | `monthly` |
| Yearly product | `yearly` |
| API key | RevenueCat **Test Store** key (sandbox / Next Gen) |

Purchases map through the **current offering**; Premium is active when:

```text
customerInfo.entitlements["safesight_pro"]?.isActive == true
```

## Free vs Premium

| | Free | Premium (`safesight_pro`) |
|--|------|---------------------------|
| Scans | **2** lifetime free scans (`SubscriptionStore.freeScanLimit`) | Unlimited |
| Focus areas | Up to **6** core areas | All focus areas |
| Core scan results | Score, hazards, boxes, share | Same |
| Home AI summary | Locked teaser | Unlocked |
| Home product picks | Locked teaser | Unlocked |
| Full Home dashboard insights | Limited | Full |

**Free focus areas:** Fire, Water leaks, Electric, Child proofing, Trip hazards, Blocked exits.

**Premium focus areas (examples):** Mold & stains, Chemical storage, Sharp objects, Stairs & falls, Windows & falls, Pet hazards, Kitchen hazards, Tip-over risks, Poor lighting, and related camera-visible categories marked `requiresPremium` on `SafetyInterest`.

Failed scans do **not** consume a free credit (credit is recorded only after a successful analysis).

## Architecture

```text
SafesightApp
  └─ Purchases.configure(apiKey)     // after first frame
  └─ SubscriptionStore.shared.start()
        ├─ PurchasesDelegate (live entitlement updates)
        ├─ customerInfo() + offerings()
        └─ isPremium ← safesight_pro

UI
  ├─ PaywallView          // custom UI → purchase(package:)
  ├─ CustomerCenterView   // manage / restore (RevenueCatUI)
  ├─ Scan / You / Home    // gate on isPremium + scanCount
  └─ Focus pickers        // strip requiresPremium when free
```

### Key types

| File | Role |
|------|------|
| `RevenueCatConfig.swift` | Entitlement + product IDs + Test Store key |
| `SubscriptionStore.swift` | Observable entitlement, offerings, purchase/restore, free-scan counters |
| `PaywallView.swift` | Custom monthly/yearly paywall; Customer Center when already Premium |
| `SafesightApp.swift` | Configure SDK once at launch (non-blocking) |

`SubscriptionStore` is `@MainActor` and owned as a singleton. It:

1. Sets `Purchases.shared.delegate` for push-style entitlement changes  
2. Loads `customerInfo` + `offerings.current`  
3. Purchases by **Store product ID** (`monthly` / `yearly`) resolved from the current offering  
4. Restores via `Purchases.shared.restorePurchases()`  
5. Keeps **local** free-scan / House Score / summary counters in `UserDefaults` (cleared on logout; RevenueCat identity is untouched)

## Paywall UX

- Entry: **Premium** tab, **You → Upgrade / Manage**, and locked Home / Scan CTAs  
- Custom branded paywall (not only the default RevenueCat template) — still buys **RevenueCat packages**  
- Yearly highlighted as best value; prices from Store / Test Store when offerings load (fallback copy if offline)  
- After purchase, the same sheet flips to “You’re on Premium” and offers **Customer Center**  
- **Restore Purchase** on the paywall; manage subscription via Customer Center when entitled  

## Where entitlement is enforced

- **Scan** — `canScan` = Premium **or** `scanCount < 2`  
- **Focus selection** (onboarding + You) — free users capped at 6 non-premium interests  
- **Home** — AI summary + product recommendations behind Premium teasers  
- **ContentView** — clamps focus set when not Premium  

Gates are client-side product rules on top of RevenueCat entitlement. The analyze API still requires the app’s API secret; Premium does not replace server auth.

## Next Gen / Test Store

From [Setup / run](./setup.md): the Test Store key in `RevenueCatConfig.swift` lets judges exercise purchase → entitlement → unlock without App Store Connect paid enrollment. For production App Store builds you’d swap to a production RevenueCat API key and real App Store products attached to the same entitlement.

## Design choice (for judges)

Premium is **capacity + depth**, not a fake wall on the first screenshot:

1. Free user can complete a meaningful scan and see boxes  
2. Hitting the scan or focus ceiling is the natural upgrade moment  
3. Home insights are the ongoing Premium surface after the house has history  

That matches the Shipaton Next Gen ask: RevenueCat wired as a real entitlement with a job in the product loop.

## Related

- [What the app does](./what-the-app-does.md) — Premium in product language  
- [Shipaton Next Gen](./shipaton-next-gen.md) — contest framing  
- [Setup / run](./setup.md) — how to run paywall locally  
- [Tech at a glance](./tech.md) — stack table  

[← Back to README](../README.md)
