# Horology Vault — Hybrid Monetization Plan

> **Revision note (2026-07-13):** Sections 1–4 below are the original product/technical plan and are
> unchanged in substance, though Section 1's tables now flag each feature's competitive position (table
> stakes vs. genuine differentiator). Sections 5 and 6 were added 2026-07-12 after reviewing the codebase
> against this plan, and are updated again as of 2026-07-13 now that Phases 1–4 of Section 6's plan have
> shipped. What used to be Sections 5–7 (SwiftUI View Hierarchy, StoreKit 2 Purchase Flow, Open Decisions)
> are renumbered to 7–9 to make room. A new **Section 10, Competitive Positioning**, was added 2026-07-13
> summarizing `horology_vault_market_research.md`'s findings, which also drove the reordering of Section 4's
> V2 rollout and two new entries in Section 9's open decisions. Read Section 5 for what's actually built
> today, Section 6 for the ordered plan to close the V1 gap, and Section 10 for why the roadmap is
> sequenced the way it is.

## 1. Feature-to-Tier Table

### One-Time Purchase (core app — local-only, zero marginal cost per user)

| Feature | Why it's core | Competitive position (see §10) |
|---|---|---|
| The Vault (dashboard/collection grid) | Pure local read of the Watches table | Table stakes |
| Fit Calculator | Local geometry math, no external data | **Differentiator** — no competitor found does geometric fit visualization |
| Strap Inventory + lug-width cross-reference | Local read/write against owned data | Table stakes (Klokker already filters existing straps by lug width) |
| Service History log + accuracy drift chart | Local read/write, no external data | Table stakes |
| Wear tracking & rotation stats | Local read/write | Table stakes |
| Maintenance reminders | Local device notifications — no server needed to schedule them | Table stakes |
| Provenance/authentication log (receipts, warranty, photos) | Local file storage | Table stakes |
| Data import/export + encrypted local backup | Local file I/O | Table stakes |
| Wishlist (static list, no live pricing) | Just a local table, no monitoring | Table stakes |
| Authorized service center directory | Static dataset, refreshed via app updates rather than a live feed | Niche — only Bezelio (service-log-only) is adjacent, nobody bundles a directory |

### Optional Subscription (needs an always-on backend — cost scales with usage)

| Feature | Why it needs a subscription | Competitive position (see §10) |
|---|---|---|
| Strap recommendations w/ live pricing + affiliate links | Requires scraping/API calls to retailers, kept fresh continuously | **Differentiator** — no competitor offers a retailer shopping/discovery feature; also the clearest monetization angle beyond the app price |
| Market value tracking | Needs a live feed of auction/marketplace comps | Table stakes — several competitors already do a manual version free |
| Wishlist price alerts | Needs a background job polling prices | Not directly validated by research, but a natural extension of the table-stakes wishlist feature |
| Cross-device cloud sync/backup | Requires hosted storage + sync infra | **Risk, not a differentiator** — WatchGrid and Watch Collector already give iCloud/CloudKit sync away free, so this alone probably can't justify a subscription (see §10 and §9) |
| Community showcase profile / trade board | Requires hosted, moderated, always-on service | Not validated by research — no competitor deep-dive covered this |
| PDF insurance appraisal with live valuation | Depends on the market-value feed above | Not validated by research |

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
- Build the **strap pricing proxy** (Section 2.4 item 1) first among the three backend services, and ship
  it before Market Value or Sync/Community — per Section 10's competitive review, Strap Recommendations is
  the one subscription feature with no competitor equivalent, so it should headline the subscription pitch
  rather than launch alongside features that read as parity with existing free tools. Consider a
  cheaply-validated MVP first (a small hand-curated affiliate link set, refreshed manually) before investing
  in full retailer scraping/API integration.
- Stand up the remaining backend services from Section 2.4 (market value feed, sync/backup store) after the
  strap feature is proven — build these only when subscription revenue is about to fund them.
- Activate the `sync_id` / `updated_at` columns already reserved in the schema and turn on the sync engine —
  but see Section 10/9's note that WatchGrid and Watch Collector already give iCloud/CloudKit sync away
  free, so Cloud Sync likely can't carry the subscription's value proposition on its own and should be
  framed as a bundled perk rather than a pillar feature.
- Turn on the subscription-gated screens in this priority order: Strap Recommendations, then Market Value,
  then Wishlist price alerts, then Cloud Sync, then Community, then Insurance PDF export.
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
- **Settings:** wrist profile editing (auto-creates a `UserProfile` if none exists), a working Data section
  (CSV import/export, encrypted backup/restore — see the Data import/export bullet below), a working
  Purchase section wired to `PurchaseManager` (see Entitlements/StoreKit bullet below), About section.
- **Maintenance reminders:** `NotificationManager` schedules a local `UNNotificationRequest` per watch on
  its computed `serviceDueDate` (`Watch.lastServiceDate ?? acquisitionDate` + 3 years, the same math
  `MaintenanceView` uses), requests authorization once at launch, and reschedules/cancels on watch create,
  edit, service log, and delete.
- **Data import/export & encrypted backup:** `DataBackupManager` wires up all four buttons in
  `SettingsView`'s Data section — CSV export/import of the watch list, and an encrypted (CryptoKit
  AES-GCM, passphrase-derived key) full-collection backup/restore covering watches, straps, service
  records, wear logs, provenance docs, wishlist items, and the wrist profile. Restore is additive rather
  than replace-all.
- **Authorized service center directory:** `OfficialServiceDirectory` (bundled, 169 manufacturers spanning
  mass-market through independent haute horlogerie, website-only contact info) plus user-added
  `CustomServiceCenter` entries, browsable/searchable in the new `ServiceCentersView` sidebar screen.
- **Entitlements + StoreKit 2:** `Entitlements` `@Model` and `PurchaseManager` (StoreKit 2, one
  non-consumable lifetime-unlock product) gate new-watch creation behind `is_lifetime_unlocked`, with a
  seeded one-watch demo state and a persistent unlock banner rather than a hard paywall — see the Phase 8
  writeup below for the two manual (non-code) steps still needed before shipping.

### 5.2 Gaps against this plan's V1 scope

Phases 1–8 of Section 6 (core CRUD gaps, Wear Log, Provenance, Fit Calculator, Maintenance reminders, Data
import/export & backup, Service center directory, Entitlements/StoreKit 2) are complete — see 5.1.
Remaining gap:

1. **Tests** — no automated tests exist for any model or view added since the default Xcode scaffold;
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

### Phase 5 — Maintenance reminders (local notifications) ✅ Done (2026-07-14)
- Added `NotificationManager.swift`, a static-only enum wrapping `UNUserNotificationCenter`:
  `requestAuthorizationIfNeeded()` (only prompts if authorization is still `.notDetermined`),
  `scheduleServiceDueReminder(for:)`, `cancelServiceDueReminder(for:)`, and `rescheduleAll(for:)`.
- Refactored `Watch.isServiceDue` to derive from a new `Watch.serviceDueDate` computed property
  (`lastServiceDate ?? acquisitionDate` + 3 years) so `MaintenanceView`'s due-list and the notification's
  due date can never disagree — both now read the same source of truth.
- `ContentView` requests authorization and reschedules every watch's reminder once at launch (`.task` with
  a `@Query private var watches: [Watch]`), which also covers watches whose data changed outside the app's
  own CRUD flows.
- Reminders are (re)scheduled from `AddWatchView.save()` (create and edit) and `AddServiceRecordView.save()`
  (logging a service resets the 3-year clock), and cancelled from both delete paths — `WatchDetailView`'s
  toolbar Delete and `VaultGridView`'s context-menu Delete.
- Notification identifiers are derived from `watch.persistentModelID` (stable from insert onward in
  SwiftData) rather than a new stored field, so no schema/migration change was needed for this phase.

### Phase 6 — Data import/export & encrypted backup ✅ Done (2026-07-14)
- Added `DataBackupManager.swift`: CSV export/import for `Watch`'s core fields (brand, model, reference
  number, complications, measurements, acquisition date — a flat format can't represent nested straps/
  service/wear/provenance, so those are left to the backup path below) via a small hand-rolled RFC4180-ish
  CSV encoder/parser (no external dependency); and an encrypted full-collection backup/restore — a
  `Codable` snapshot of every `Watch` (with its embedded service records, wear logs, and provenance docs),
  every `Strap` (linked back to its watch by array index within the same payload), `WishlistItem`s, and the
  `UserProfile`, JSON-encoded and sealed with CryptoKit `AES.GCM` using a key derived from a user-entered
  passphrase (`SHA256` hash, no PBKDF2/salt — this only needs to deter casual access to a local file, not
  resist a targeted offline attack, so the added complexity wasn't worth it for V1).
- Wired all four buttons in `SettingsView`'s Data section to real actions: CSV export/import use
  `.fileExporter`/`.fileImporter` with `FileDocument`-conforming `CSVDocument`/`BackupDocument` wrapper
  types; the encrypted backup/restore paths prompt for a passphrase via a `SecureField`-based `.alert`
  before sealing/opening the file.
- **Restore is additive, not destructive:** imported records are inserted alongside whatever's already in
  the store rather than replacing the collection outright, since a silent full wipe-and-replace is a much
  easier way to lose data than a merge is to create duplicates. Revisit this if users ask for true
  replace-on-restore — flagged as an open decision in Section 9.
- Restoring a backup also calls `NotificationManager.rescheduleAll(for:)` so newly-restored watches get
  their maintenance reminders immediately rather than waiting for the next app launch.

### Phase 7 — Authorized service center directory ✅ Done (2026-07-14)
- Added `OfficialServiceDirectory.swift`: a bundled, read-only list of official service/support entry
  points, grown in two passes — an initial 16 major manufacturers (Rolex, Tudor, Omega, Seiko, Grand Seiko,
  TAG Heuer, Breitling, IWC, Panerai, Cartier, Longines, Citizen, Hamilton, Casio, Hublot, Tissot), then
  expanded to 169 total brands by working through the full brand index at thewatchpages.com/brands (Swiss
  haute horlogerie houses, independent ateliers, and enthusiast brands from A. Lange & Söhne through ZRC).
  Each entry is root-domain-only (e.g. `rolex.com`) — deliberately no phone numbers or street addresses,
  since third-party listings for those are frequently stale or wrong, which is worse than omitting them for
  something as high-stakes as where to send an expensive watch. Domains were either already confidently
  known or verified via web search (never guessed) before being added; three brands from that source list
  were deliberately excluded — Claude Meylan and Emmanuel Bouchet (no confident official site found) and
  Purnell (ceased operating/bankrupt as of December 2024, so there's no active support to point to).
  Implemented as a Swift literal array rather than a bundled JSON resource file, to get the same
  static/read-only/ships-with-the-app effect without hand-editing the Xcode project file to register a new
  bundle resource.
  - **Open decision resolved during implementation:** the plan originally scoped this as manufacturer-only
    reference content; the actual build also lets users add their own entries (a local watchmaker, an
    independent shop) via a new `CustomServiceCenter` `@Model` (name, brand, phone, website, address,
    notes), registered in the schema. This was an explicit ask, not scope creep — a collector's actual
    trusted service contact is often independent, not the manufacturer.
- Added `ServiceCentersView.swift`: a searchable (`.searchable`) List with two sections — "Manufacturer
  Support" (the bundled directory, read-only) and "My Service Centers" (`CustomServiceCenter` entries, with
  a "+" toolbar button opening an `AddServiceCenterView` sheet and swipe-to-delete). Search filters both
  sections by brand or name.
- Added "Service Centers" as a 6th sidebar entry in `ContentView.Section` (between Maintenance and
  Settings), matching the precedent Phase 4 set for Fit Calculator.

### Phase 8 — Entitlements + StoreKit 2 (V1 monetization) ✅ Done (2026-07-14)
Deliberately last: gating features is cheap to retrofit once, expensive to keep re-doing as new screens
land.
- Added the `Entitlements` `@Model` from Section 2.2 (`isLifetimeUnlocked`, `subscriptionStatus` —
  `SubscriptionStatus` enum: `none`/`active`/`expired`/`gracePeriod`, `subscriptionExpiresAt`,
  `lastValidatedAt`), registered in the `Schema`. Exactly one row is expected to exist; the UI only ever
  reads this table, never StoreKit directly, per Section 2.2's design.
- Built `PurchaseManager.swift` (an `@Observable` class) matching Section 8's five responsibilities:
  `loadProduct()` (`Product.products(for:)`), a `Transaction.updates` listener started from `configure(modelContext:)`,
  `purchase()`, `reconcileEntitlementsOnLaunch()` (walks `Transaction.currentEntitlements` and writes the
  result to the `Entitlements` row), and `restorePurchases()` (`AppStore.sync()` + reconcile).
  `.userCancelled`/`.pending` are no-ops, not errors, matching the plan's spec.
- Added `Configuration.storekit` (a local StoreKit Testing configuration with one non-consumable product,
  `com.angelburgos.HorologyVault.lifetime`) so the purchase flow is testable in Xcode/Simulator without a
  live App Store Connect record. **Two manual, non-code steps remain before shipping:** (1) in Xcode, Edit
  Scheme → Run → Options → StoreKit Configuration → select `Configuration.storekit`, so local runs use the
  test product; (2) register the same product ID in App Store Connect for the real listing.
- Implemented the demo-mode gating this plan specifies: `ContentView` seeds exactly one sample watch (a
  Rolex Explorer) plus an `Entitlements()` row on a truly empty first launch (gated on both `entitlements`
  and `watches` being empty, so an existing user's real collection is never touched), and `VaultGridView`
  disables its "Add Watch" toolbar button and shows a persistent "Unlock Full Version" banner (calling
  `purchaseManager.purchase()` directly) whenever `entitlements.first?.isLifetimeUnlocked` is false — no
  hard paywall on launch. *Scope note:* only the Vault's "Add Watch" action is gated, not every "+" button
  app-wide (Straps/Wishlist/Service Centers/etc. stay open) — the plan's own example ("Add Watch disabled")
  points at this one choke point, and it's the natural one since a demo user only has the one seeded watch
  to explore anyway.
- Wired `SettingsView`'s Purchase section to the real `PurchaseManager`: shows "Full Version" vs.
  "Demo (Read-Only)" based on the `Entitlements` row, an "Unlock Full Version — \(price)" button when
  locked, and a working "Restore Purchase" button, plus an inline error line if `purchaseManager.lastError`
  is set.

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
- Fit Calculator
- Wishlist
- Maintenance
- Service Centers
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

**Service Centers**
- Searchable list of official manufacturer service/support contacts (bundled, read-only) plus user-added
  custom entries (name, brand, phone, website, address, notes), with add/delete for the custom ones.

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
- **(Added 2026-07-13, from market research)** Whether Cloud Sync can be a paid subscription feature at
  all, given WatchGrid and Watch Collector already offer iCloud/CloudKit sync for free — it may need to
  ship free in V1 or as a bundled perk of the subscription rather than a pillar reason to subscribe.
- **(Added 2026-07-13, from market research)** Whether to build a minimal Strap Recommendations MVP (a
  small hand-curated set of affiliate links, refreshed manually) before investing in the full
  scraping/API-driven pricing proxy from Section 2.4 — validates the app's clearest differentiator cheaply
  before committing ongoing backend cost to it.
- **(Added 2026-07-14, from Phase 6)** Whether "Restore from Backup" should stay additive (current
  behavior — imported records are inserted alongside the existing collection) or gain a true
  replace-all-with-backup mode; additive was chosen to avoid a silent full-collection wipe, but a power
  user restoring onto a fresh install may expect exact replacement instead.

## 10. Competitive Positioning (Market Research, 2026-07-13)

Summarizes `horology_vault_market_research.md` at the repo root — read that document for the full
competitor-by-competitor detail (WatchGrid, Klokker, Watch Collector, Watch Collection Tracker, iCollect
Everything, and ~20 more apps surveyed but not deep-dived).

**Bottom line:** the watch-collection-tracker category is real but crowded — a dozen-plus actively
maintained apps exist, almost all solo-developer-built, but none has run away with the category (ratings
volumes are small across the board). Two features from this plan — the **Fit Calculator** and **Strap
recommendations with live pricing/affiliate links** — do not appear in any competitor found. Viability
depends on executing those two well, not on the category being underserved.

**What's table stakes, not a differentiator:** wear tracking with a calendar/rotation view, service/accuracy
history, manual market value tracking, wishlist, photo storage, and — notably — **free** cloud sync
(iCloud/CloudKit, offered at no charge by WatchGrid and Watch Collector). This plan's Vault, Service
History, WearLog, Wishlist, and Provenance features map directly onto this baseline: necessary to be
competitive, but not why anyone would choose this app over Klokker or WatchGrid. Section 1's tables above
are now annotated feature-by-feature with this distinction.

**What's genuinely unclaimed:** the Fit Calculator (comparing lug-to-lug against the user's own wrist
geometry — Klokker only has a lug-width *filter* against the user's existing strap inventory, not
geometric fit visualization) and Strap Recommendations with affiliate links (no competitor offers retailer
shopping/discovery for straps at all). These are this plan's only two genuinely unclaimed features and its
clearest monetization angle beyond the app price itself.

**Pricing pattern validates this plan's hybrid model:** every dedicated competitor with a paywall uses a
one-time unlock ($3.99–$12.99), not a subscription. This confirms collectors in this niche expect and
respond to one-time pricing — a subscription-only app would likely underperform on conversion. The
one-time-core-plus-optional-subscription split in Sections 1–2 fits the observed market better than either
pure model.

**Risk:** shipping "just another watch tracker" without the Fit Calculator and Strap Recommendations
executed distinctly means competing on parity against apps (WatchGrid, Klokker especially) that already
have a head start and loyal small communities.

**Resulting changes made to this plan:**
1. Section 1's tables now carry a "Competitive position" column, tagging Fit Calculator and Strap
   Recommendations as differentiators and flagging Cloud Sync as a risk rather than a subscription pillar.
2. Section 4's V2 rollout now builds and ships Strap Recommendations first among the three backend
   services, ahead of Market Value and Sync/Community, with an MVP-first suggestion to validate it cheaply.
3. Section 9 gained two new open decisions: whether Cloud Sync can carry a subscription on its own, and
   whether to MVP the strap pricing proxy before building the full scraping/API integration.
- No changes were made to Section 6's V1 phase ordering (Phases 5–9) — the market research is about V2/
  subscription positioning and doesn't change what's needed to finish the local-only V1 feature set.
