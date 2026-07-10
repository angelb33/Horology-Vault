# Horology Vault — Hybrid Monetization Plan

## 1. Feature-to-Tier Table

### One-Time Purchase (core app — local-only, zero marginal cost per user)

| Feature | Why it's core |
|---|---|
| The Vault (dashboard/collection grid) | Pure local read of the Watches table |
| Fit Calculator | Local geometry math, no external data |
| Strap Inventory + lug-width cross-reference | Local read/write against owned data |
| Service History log + accuracy drift chart | Local read/write, no external data |
| Wear tracking & rotation stats | Local read/write |
| Maintenance reminders | Local device notifications — no server needed to schedule them |
| Provenance/authentication log (receipts, warranty, photos) | Local file storage |
| Data import/export + encrypted local backup | Local file I/O |
| Wishlist (static list, no live pricing) | Just a local table, no monitoring |
| Authorized service center directory | Static dataset, refreshed via app updates rather than a live feed |

### Optional Subscription (needs an always-on backend — cost scales with usage)

| Feature | Why it needs a subscription |
|---|---|
| Strap recommendations w/ live pricing + affiliate links | Requires scraping/API calls to retailers, kept fresh continuously |
| Market value tracking | Needs a live feed of auction/marketplace comps |
| Wishlist price alerts | Needs a background job polling prices |
| Cross-device cloud sync/backup | Requires hosted storage + sync infra |
| Community showcase profile / trade board | Requires hosted, moderated, always-on service |
| PDF insurance appraisal with live valuation | Depends on the market-value feed above |

**Rule of thumb used for the split:** if a feature only ever touches data the user already owns on their device, it belongs in the one-time tier. If it depends on data that changes without the user's input (prices, comps, other users' posts), it belongs in the subscription tier, because that's the piece that costs you money to keep running.

---

## 2. Technical Architecture

### 2.1 Local data layer (SQLite, always present, works fully offline)

Existing core tables — unchanged:
- `Watches` (brand, model, complications, case_diameter_mm, lug_to_lug_mm, lug_width_mm)
- `Straps` (material, width_mm, is_attached_to)
- `ServiceHistory` (watch_id, date_performed, service_type, accuracy_delta_spd)
- `UserProfile` (wrist_top_width_cm, wrist_side_depth_cm)

New core tables for the added features:
- `WearLog` (id, watch_id FK, date_worn, notes)
- `Wishlist` (id, brand, model, target_price, notes, price_alert_enabled BOOL default false)
- `ProvenanceDocs` (id, watch_id FK, doc_type [receipt/warranty/appraisal], file_path, date_added)

All of the above are populated and queried entirely on-device, regardless of subscription status.

### 2.2 Entitlement layer (the tier gate)

A single local table drives all feature gating:

`Entitlements` (
  is_lifetime_unlocked BOOL,
  subscription_status ENUM[none, active, expired, grace_period],
  subscription_expires_at DATE,
  last_validated_at DATETIME
)

- On purchase, the app validates the receipt (StoreKit / Google Play Billing on mobile, or a license key from Stripe/Paddle/Gumroad on desktop) and writes the result here.
- The UI never talks to the store/payment provider directly — every screen just reads this one table, which means the app works correctly offline using the last validated state.
- Revalidate in the background whenever the app has connectivity; allow a short grace period (e.g. 3–7 days) before locking subscription features if revalidation fails, so a spotty connection doesn't lock out a paying user.

### 2.3 Feature gating

Screens split cleanly into two buckets based on a single check:

- `is_lifetime_unlocked == true` → Vault, Fit Calculator, Strap Inventory, Service History, WearLog, Maintenance reminders, Provenance, import/export/backup, static Wishlist.
- `subscription_status == active` → Strap Recommendations, Market Value, Wishlist price alerts, Cloud Sync, Community, Insurance PDF export.

If a subscription-gated screen is opened without an active subscription, show an upsell/paywall instead of the feature — never a broken or empty state.

### 2.4 Backend services (only needed for the subscription tier)

This is the only part of the system that requires servers, and it's exactly what the subscription revenue is meant to fund:

1. **Strap catalog/pricing proxy** — aggregates retailer catalogs (Barton, StrapsCo, Delugs, Hemsut, WatchDives, etc.), attaches affiliate links, refreshed on a schedule.
2. **Market value service** — aggregates auction/marketplace comps per brand/model/reference number to produce a value estimate.
3. **Sync/backup store** — per-user encrypted blob storage for cross-device continuity.
4. **Community feed** — hosted, moderated posts/showcase data.

### 2.5 Sync engine (subscribers only)

Add `sync_id` and `updated_at` columns to `Watches`, `Straps`, `ServiceHistory`, `WearLog`, and `Wishlist`. These columns sit unused for one-time-only users. When a user subscribes, the sync engine activates: local changes push to the backend on a timer, and pulls resolve conflicts by latest `updated_at` wins (with a manual merge prompt if both sides changed the same record since last sync).

### 2.6 Payment implementation notes

- **Mobile (iOS/Android):** both the one-time unlock and the subscription must go through StoreKit / Google Play Billing — you can't process either payment yourself, and the platform takes its standard cut of both. Validate receipts server-side to prevent spoofing, then cache the result in `Entitlements`.
- **Desktop, sold outside app stores (Stripe/Paddle/Gumroad):** the one-time purchase issues a license key that can be validated once and used offline indefinitely; the subscription bills recurring and needs a periodic (not necessarily constant) online check.

---

## 3. Platform Scope: Apple Only (iOS + macOS)

**Decision:** build for iOS and macOS first, via a single SwiftUI multiplatform target. Skip Android/Windows until the core app has proven demand.

**Why:** watch collectors are a heavily Apple-skewed audience, and SwiftUI shares the large majority of code between iPhone and Mac — same data models, same business logic (fit calculator math, entitlement checks), UI adapts per screen size and input method (touch vs. pointer/keyboard). This keeps one team and one codebase instead of maintaining separate native apps or adopting a cross-platform framework before you need one.

**Stack notes:**
- **Persistence:** SQLite via GRDB or SwiftData, shared identically between iOS and macOS targets.
- **Payments:** StoreKit 2 for both the one-time unlock and (later) the subscription — Apple's modern Transaction API handles non-consumable in-app purchases and auto-renewable subscriptions through the same listener, so the entitlement-checking code barely changes when the subscription is added later.
- **Distribution:** Mac App Store + iOS App Store. Both go through App Store Connect as separate listings sharing one codebase. Selling the Mac app outside the Mac App Store (to avoid Apple's cut) is possible later, but starting inside both stores keeps StoreKit entitlement logic unified across platforms from day one.

## 4. Roadmap

### V1 — One-time purchase only (ship now)
- Platforms: iOS + macOS.
- Scope: every feature in the **One-Time Purchase** table in Section 1 — Vault, Fit Calculator, Strap Inventory, Service History, WearLog, maintenance reminders, Provenance, import/export/backup, static Wishlist, service-center directory.
- `Entitlements` table exists and is checked by the UI, but `subscription_status` is hardcoded to `none` and no subscription screens or paywalls are shown.
- No backend, no hosting cost. StoreKit 2 handles the one-time non-consumable purchase.

### V2 — Add the subscription (later, once V1 has traction)
- Add a StoreKit 2 auto-renewable subscription product; entitlement code extends the existing check rather than being rewritten.
- Stand up the three backend services from Section 2.4 (strap pricing proxy, market value feed, sync/backup store) — build these only when subscription revenue is about to fund them.
- Activate the `sync_id` / `updated_at` columns already reserved in the schema and turn on the sync engine.
- Turn on the subscription-gated screens: Strap Recommendations, Market Value, Wishlist price alerts, Cloud Sync, Community, Insurance PDF export.
- Existing V1 customers see this as a new optional upsell in an app update — no migration, no breaking changes to their local data.

## 5. SwiftUI View Hierarchy (V1)

Root: a single `NavigationSplitView` — renders as a sidebar + content + detail 3-column layout on macOS/iPad, and collapses to a stack on iPhone. This is the standard SwiftUI pattern for one codebase that adapts to both platforms.

**Sidebar (top-level sections):**
- Vault (default/home)
- Wishlist
- Maintenance
- Settings
- *(V2, hidden until subscription ships)* Strap Shop · Market Value · Community

**Vault**
- `VaultGridView` — grid of `WatchCardView` (photo, brand/model, service-due indicator). Sort by brand, acquisition date, or case size.
- Tap a card → `WatchDetailView` ("the Workbench"), with sections:
  - *Overview* — specs, complications, photo.
  - *Straps* — currently attached strap, plus an "Attach Strap" picker filtered to `Straps` rows matching this watch's `lug_width_mm`.
  - *Service History* — timeline list + an accuracy-drift line chart (Swift Charts) plotting `accuracy_delta_spd` over time.
  - *Wear Log* — list of `WearLog` entries plus a one-tap "Log today" button.
  - *Provenance* — attached `ProvenanceDocs` (receipts, warranty, appraisals).
  - *Fit Preview* — this watch's `lug_to_lug_mm` plotted against the user's saved wrist geometry.
- `+` button → `AddWatchView` (form: brand, model, complications multi-select, case_diameter_mm, lug_to_lug_mm, lug_width_mm, photo).

**Fit Calculator** (reachable standalone, or from a Workbench)
- `FitCalculatorView` — pick a watch, renders a 2D top-down diagram (SwiftUI `Canvas`) comparing `lug_to_lug_mm` against `wrist_top_width_cm`.

**Wishlist**
- Simple list view; each row has brand/model/target price/notes. *(Price-alert toggle exists in the row UI but is disabled/grayed out until V2.)*

**Maintenance**
- Cross-collection list of upcoming/overdue service items, sorted by due date — this is what drives the local notification reminders, so the screen and the notification scheduling share one query.

**Settings**
- Wrist profile (`wrist_top_width_cm`, `wrist_side_depth_cm`).
- Data: CSV import/export, encrypted local backup/restore.
- Purchase status: shows unlock state, includes a **Restore Purchase** button (still recommended even with StoreKit 2's automatic entitlement sync — Apple's review guidelines expect one).
- About/support.

**Shared components used across screens:** `WatchCardView`, `AccuracyChartView` (Swift Charts), `FitDiagramView` (Canvas), `StrapPickerView` (filtered by lug width) — building these once as reusable views is what keeps the iOS and macOS targets from diverging.

## 6. StoreKit 2 Purchase Flow (V1 — one-time unlock only)

**Product:** a single non-consumable in-app purchase, e.g. `com.yourapp.horologyvault.lifetime`.

**`PurchaseManager` (an `@Observable` class shared by both targets) is responsible for:**
1. Loading the product via `Product.products(for:)` on launch.
2. Running a background `Task` that listens to `Transaction.updates` — this catches purchases completed on another device or interrupted mid-flow, which matters more on macOS where a purchase sheet can be dismissed unexpectedly.
3. `purchase()` — calls `product.purchase()`, and on `.success(.verified(transaction))`, calls `transaction.finish()` and writes `is_lifetime_unlocked = true` into the local `Entitlements` table.
4. On every app launch, iterating `Transaction.currentEntitlements` to reconcile the local `Entitlements` table with what StoreKit actually has on record — this is what makes "Restore Purchase" mostly automatic, since StoreKit 2 syncs entitlements without the user needing to do anything.
5. Handling `.userCancelled` and `.pending` (e.g., Ask to Buy / parental approval) states without treating them as errors.

**Gating decision for V1:** rather than a hard paywall on first launch, let the app open in a read-only demo state (e.g., one sample watch pre-loaded, "Add Watch" disabled) with a persistent "Unlock Full Version" prompt. This lets a browser see the Vault and Fit Calculator before paying — usually converts better than a paywall with nothing to look at, and costs nothing extra to build since it's just the existing `is_lifetime_unlocked` check gating the `+` buttons instead of the whole app.

**Tie-back to the Entitlements table:** this is exactly the same table designed in Section 2.2 — `PurchaseManager` is simply the iOS/macOS-specific code that keeps `is_lifetime_unlocked` accurate. When V2 adds the subscription, the same class gains a second product and starts also writing `subscription_status`, with no changes needed to how the UI reads that table.

## 7. Open Decisions

- Subscription price point and whether it's monthly-only or offers an annual discount.
- Whether Wishlist price alerts ship at launch of V2 or as a fast-follow (it's the smallest of the subscription features and could be a good "prove the subscription is worth it" hook).
- Whether the service-center directory should eventually move from bundled/static to a live-updated dataset (would shift it into the subscription bucket).
- Whether/when to expand beyond Apple to Android/Windows, and if so, whether that means a Flutter rewrite or native ports.
