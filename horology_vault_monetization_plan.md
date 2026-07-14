# Horology Vault — Hybrid Monetization Plan

> **Revision note (2026-07-13):** Sections 1–4 below are the original product/technical plan and are
> unchanged. Sections 5 and 6 were added 2026-07-12 after reviewing the codebase against this plan, and are
> updated again as of 2026-07-13 now that Phases 1–4 of Section 6's plan have shipped. What used to be
> Sections 5–7 (SwiftUI View Hierarchy, StoreKit 2 Purchase Flow, Open Decisions) are renumbered to 7–9 to
> make room. Read Section 5 for what's actually built today and Section 6 for the ordered plan to close the
> gap with V1 scope.

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

## 5. Implementation Status (as of 2026-07-13)

### 5.1 Built so far

- **Data layer:** `Watch`, `Strap`, `ServiceRecord`, `UserProfile`, `WishlistItem`, `WearLog`, and
  `ProvenanceDoc` SwiftData models exist and are registered in the `Schema([...])` in
  `Horology_Vault_App.swift`. `Watch` also carries a `referenceNumber: String?` (manufacturer reference
  number, e.g. "214270") that wasn't in the original data model but fits naturally alongside brand/model.
  `WearLog` (`dateWorn`, `notes`) and `ProvenanceDoc` (`docType` enum: receipt/warranty/appraisal,
  `.externalStorage` file data, `fileName`, `dateAdded`) both cascade-delete with their owning `Watch`, same
  as `ServiceRecord`. `Strap` gained optional `name`, `lengthMM`, and `notes` fields plus a `summary`
  computed property used consistently in pickers/labels.
- **Navigation shell:** `ContentView` hosts the root `NavigationSplitView` with the sidebar sections this
  plan calls for — Vault, Fit Calculator, Wishlist, Maintenance, Settings — matching Section 7 below.
- **Vault:** `VaultGridView` (adaptive grid, sort by brand/acquisition date/case size, empty state, "+" →
  `AddWatchView` sheet, context-menu Delete with a `confirmationDialog`) → `WatchCardView` (photo thumbnail
  smart-cropped via on-device Vision saliency detection so the crop centers on the subject rather than the
  frame's geometric center, service-due badge) → `WatchDetailView` ("the Workbench") with Overview / Straps
  / Service History / Wear Log / Provenance / Fit Preview sections, plus toolbar Edit and destructive Delete
  actions.
- **`AddWatchView`** handles both create and edit — an "Edit" button on `WatchDetailView` reopens the same
  sheet pre-filled via a `watchToEdit` parameter. Photo capture uses `PhotosPicker` on iOS and a native file
  importer on macOS (so it can reach any file on disk, not just what's imported into Photos.app).
- **`AccuracyChartView`** plots `accuracyDeltaSPD` over time via Swift Charts, with an empty state.
- **Log Service / Add Strap / Log Wear / Add Provenance Doc:** `WatchDetailView` now has a working create
  flow for every section it shows — "Log Service…" opens `AddServiceRecordView` (date, service type,
  accuracy delta), the Straps section's "Add New Strap…" opens `AddStrapView` (name, material, width,
  length, notes) and immediately attaches the new strap, "Log Today" inserts a `WearLog` entry directly, and
  "Add Document…" opens `AddProvenanceDocView` (doc type picker + `.fileImporter` for PDF/image) with
  swipe-to-delete on the resulting list. All three sheet views are private structs defined inside
  `WatchDetailView.swift`.
- **Fit Calculator:** `FitDiagramView` (a `Canvas`-based top-down diagram comparing lug-to-lug against
  wrist width, with a fits/overhangs verdict) is both a standalone sidebar screen (`FitCalculatorView` —
  pick a watch, see the diagram) and embedded in `WatchDetailView`'s Fit Preview section, replacing the old
  side-by-side numbers.
- **Wishlist:** `WishlistView` (sorted list, empty state, swipe-to-delete, add sheet); the price-alert
  toggle is present in the row UI but disabled pending V2.
- **Maintenance:** `MaintenanceView` splits watches into Service Due / Up to Date via `Watch.isServiceDue`
  (3-year interval), rows push into `WatchDetailView`.
- **Settings:** wrist profile editing (auto-creates a `UserProfile` if none exists), stubbed/disabled Data
  section (CSV import/export, encrypted backup/restore), stubbed Purchase section (hardcoded "Full
  Version" label, disabled Restore Purchase button), About section.

### 5.2 Gaps against this plan's V1 scope

Phases 1–4 of Section 6 (core CRUD gaps, Wear Log, Provenance, Fit Calculator) are complete — see 5.1.
Remaining gaps, in the order Section 6 tackles them:

1. **Maintenance reminders** — `MaintenanceView` surfaces overdue watches when the screen is opened, but
   nothing schedules an actual local notification; this plan calls for that screen's query to double as
   what drives `UNNotificationRequest` scheduling.
2. **Data import/export & encrypted backup** — the Data section's buttons in Settings are no-ops.
3. **Authorized service center directory** — not implemented; no bundled dataset or view exists yet.
4. **Entitlements** — table doesn't exist. Nothing in the app currently reads or writes any unlock state —
   the app is fully open with zero gating, so none of the demo-mode scaffolding Section 8 (StoreKit 2
   Purchase Flow) calls for is in place yet.
5. **StoreKit 2 / `PurchaseManager`** — not started. The Purchase section in Settings is inert UI only.
6. **Tests** — no automated tests exist for any model or view added since the default Xcode scaffold;
   `Horology VaultTests` still only has the example Swift Testing case.

## 6. Next Implementation Steps (Ordered Plan)

Ordered to finish the local, fully-offline V1 feature set (Sections 1 and 5) before touching entitlements
or StoreKit — gating a feature set that isn't finished yet just adds rework. Each phase lists its
deliverables and the files it primarily touches.

### Phase 1 — Close the core CRUD gaps ✅ Done (2026-07-13)
The three most-used workflows in a "log everything about my watches" app were missing their "create" step,
which made the rest of the Workbench feel like a read-only display.

- **Log Service:** ~~add~~ Added an `AddServiceRecordView` sheet (date performed, service type, accuracy
  delta in sec/day) opened from a new button in `WatchDetailView`'s Service History section.
- **Add/attach Strap:** ~~add~~ Added an `AddStrapView` sheet (name, material, width, length, notes)
  reachable from the Straps section's "Add New Strap…" button, which attaches the new strap immediately on
  save. *Open decision (still open):* this plan's Section 1 lists "Strap Inventory" as its own feature,
  which could eventually justify a dedicated Straps sidebar screen (browse/edit all straps independent of
  any one watch) rather than creating them inline per-watch. Current implementation is inline creation from
  the Workbench, since that's the only place straps are consumed today — revisit a standalone screen only
  if strap reuse across many watches turns out to be common.
- **Delete Watch:** ~~add~~ Added a context-menu Delete on `VaultGridView`'s grid cards (swipe doesn't apply
  to a grid) and a destructive toolbar "Delete" action in `WatchDetailView`, both gated by a
  `confirmationDialog`, mirroring the pattern `WishlistView` already uses.

### Phase 2 — Wear Log ✅ Done (2026-07-13)
- Added a `WearLog` `@Model` (`dateWorn`, `notes`, back-reference to `Watch`, cascade-deleted with the watch
  like `ServiceRecord`), registered in the `Schema`.
- Replaced `WatchDetailView`'s placeholder Wear Log section with a "Log Today" button plus a list of past
  entries sorted newest-first. Rotation stats (Section 1's "wear tracking & rotation stats") are still a
  fast-follow, not yet built — treat as a follow-up once there's enough logged data to make a stat
  meaningful.

### Phase 3 — Provenance ✅ Done (2026-07-13)
- Added a `ProvenanceDoc` `@Model` (`docType` enum: receipt/warranty/appraisal, `fileData` as
  `@Attribute(.externalStorage) Data`, `fileName`, `dateAdded`, back-reference to `Watch`, cascade-deleted
  with the watch) — the externalStorage blob approach was chosen over a `file_path`, same reasoning as
  `Watch.photoData`: a copied blob can't go stale the way a path to a user-moved/deleted file can.
- Replaced `WatchDetailView`'s placeholder Provenance section with an `AddProvenanceDocView` sheet (doc
  type picker + `.fileImporter` for PDF/image — used on both platforms here rather than the iOS
  PhotosPicker/macOS fileImporter split `AddWatchView` uses for photos, since receipts/warranties are
  documents that don't live in the Photos library on either platform) and a list of attached docs with
  swipe-to-delete.

### Phase 4 — Fit Calculator ✅ Done (2026-07-13)
- Built `FitDiagramView` using SwiftUI `Canvas` — a 2D top-down comparison of a watch's `lugToLugMM`
  against the user's `wristTopWidthCM`, with a fits/overhangs verdict, per Section 7's spec.
- Built a standalone `FitCalculatorView` (pick a watch, see the diagram), reachable as a 5th sidebar entry
  in `ContentView.Section` (between Vault and Wishlist) as well as from `WatchDetailView`'s Fit Preview
  section.
- Upgraded `WatchDetailView`'s Fit Preview section to embed `FitDiagramView` instead of the previous
  side-by-side numbers.

### Phase 5 — Maintenance reminders (local notifications)
- Request notification authorization (once, e.g. from `SettingsView` or on first watch add).
- Schedule a `UNNotificationRequest` per watch when it crosses into service-due territory, driven by the
  same `isServiceDue`/due-date query `MaintenanceView` already uses, and reschedule on service log / watch
  edit / delete.

### Phase 6 — Data import/export & encrypted backup
- Wire up the four no-op buttons in `SettingsView`'s Data section: CSV export/import for `Watch` (and
  probably `Strap`/`ServiceRecord`), and an encrypted local backup/restore (e.g. CryptoKit-encrypted JSON
  snapshot of the SwiftData store to a file the user picks via the same macOS file-importer / iOS
  document-picker pattern already in place).

### Phase 7 — Authorized service center directory
- Add a bundled static dataset (JSON in the app bundle) and a simple browse/search view. Lowest priority of
  the remaining local features since it's static reference content rather than user data.

### Phase 8 — Entitlements + StoreKit 2 (V1 monetization)
Deliberately last: gating features is cheap to retrofit once, expensive to keep re-doing as new screens
land.
- Add the `Entitlements` `@Model` from Section 2.2, register it in the `Schema`.
- Build `PurchaseManager` per Section 8 (below, an `@Observable` class: loads the product, listens to
  `Transaction.updates`, `purchase()`, reconciles `Transaction.currentEntitlements` on launch).
- Register the non-consumable lifetime-unlock product in App Store Connect (manual dashboard step, not
  code).
- Implement the demo-mode gating this plan specifies: app opens read-only with `+`/create actions disabled
  until `is_lifetime_unlocked`, with a persistent "Unlock Full Version" prompt rather than a hard paywall.
- Wire `SettingsView`'s Purchase section to the real `PurchaseManager` (live unlock state, working Restore
  Purchase).

### Phase 9 — Tests
Add coverage incrementally alongside each phase above rather than as one giant batch at the end, prioritizing:
- Fit Calculator math (Phase 4) — this is pure geometry, the highest-value thing to unit test.
- `Entitlements`/`PurchaseManager` gating logic (Phase 8) — a broken paywall either leaks the paid feature
  set or locks out a paying customer, both expensive mistakes to ship silently.
- Model invariants that already exist but are untested (e.g. `Watch.isServiceDue`, cascade-delete behavior
  on `Watch` → `ServiceRecord`/`WearLog`/`ProvenanceDocs`).

## 7. SwiftUI View Hierarchy (V1)

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

## 8. StoreKit 2 Purchase Flow (V1 — one-time unlock only)

**Product:** a single non-consumable in-app purchase, e.g. `com.yourapp.horologyvault.lifetime`.

**`PurchaseManager` (an `@Observable` class shared by both targets) is responsible for:**
1. Loading the product via `Product.products(for:)` on launch.
2. Running a background `Task` that listens to `Transaction.updates` — this catches purchases completed on another device or interrupted mid-flow, which matters more on macOS where a purchase sheet can be dismissed unexpectedly.
3. `purchase()` — calls `product.purchase()`, and on `.success(.verified(transaction))`, calls `transaction.finish()` and writes `is_lifetime_unlocked = true` into the local `Entitlements` table.
4. On every app launch, iterating `Transaction.currentEntitlements` to reconcile the local `Entitlements` table with what StoreKit actually has on record — this is what makes "Restore Purchase" mostly automatic, since StoreKit 2 syncs entitlements without the user needing to do anything.
5. Handling `.userCancelled` and `.pending` (e.g., Ask to Buy / parental approval) states without treating them as errors.

**Gating decision for V1:** rather than a hard paywall on first launch, let the app open in a read-only demo state (e.g., one sample watch pre-loaded, "Add Watch" disabled) with a persistent "Unlock Full Version" prompt. This lets a browser see the Vault and Fit Calculator before paying — usually converts better than a paywall with nothing to look at, and costs nothing extra to build since it's just the existing `is_lifetime_unlocked` check gating the `+` buttons instead of the whole app.

**Tie-back to the Entitlements table:** this is exactly the same table designed in Section 2.2 — `PurchaseManager` is simply the iOS/macOS-specific code that keeps `is_lifetime_unlocked` accurate. When V2 adds the subscription, the same class gains a second product and starts also writing `subscription_status`, with no changes needed to how the UI reads that table.

## 9. Open Decisions

- Subscription price point and whether it's monthly-only or offers an annual discount.
- Whether Wishlist price alerts ship at launch of V2 or as a fast-follow (it's the smallest of the subscription features and could be a good "prove the subscription is worth it" hook).
- Whether the service-center directory should eventually move from bundled/static to a live-updated dataset (would shift it into the subscription bucket).
- Whether/when to expand beyond Apple to Android/Windows, and if so, whether that means a Flutter rewrite or native ports.
