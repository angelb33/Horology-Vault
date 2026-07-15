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
>
> **Revision note (2026-07-14):** Two new V1-scope, local-only features were added after the original 9
> phases closed out: **Appearance (light/dark mode + accent color theming)** and a new **Insights** sidebar
> screen (wear frequency, service status, and wear-vs-maintenance trend charts). Section 1's one-time-purchase
> table gained two rows for these; Section 6 gained **Phase 10** and **Phase 11**, both implemented and
> shipped the same day — build succeeds, full test suite passing at 37/37, and the UI itself (appearance
> toggles, all four charts) was manually verified by the user directly in Xcode, since the sandbox this work
> was implemented in has no Screen Recording/Apple Events permission to do that verification itself. Neither
> feature needed a schema change beyond one new computed property on `Watch` (see Phase 11) — both build
> entirely on data the app already collects.
>
> **Revision note (2026-07-15):** Added **Phase 12, Scheduled Automatic Encrypted Backup** — reuses the
> existing manual encrypted backup format with a Keychain-stored passphrase and a user-picked destination
> folder, on a Daily/Weekly/Monthly schedule, fully silent once configured. New files: `KeychainHelper.swift`
> (no Keychain code existed before this) and `ScheduledBackupManager.swift` (the first `#if os(...)`
> branching in this app's scheduling code — iOS's `BGTaskScheduler` and macOS's
> `NSBackgroundActivityScheduler` are unrelated APIs). Two platform-configuration unknowns were resolved
> empirically rather than assumed: iOS needed a small supplemental `Info-iOS-BackgroundTasks.plist` merged
> in via `INFOPLIST_FILE` (custom keys like `BGTaskSchedulerPermittedIdentifiers` don't synthesize through
> this project's `INFOPLIST_KEY_*` build settings the way its other Info.plist keys do), while macOS needed
> no new entitlement — the `com.apple.security.files.user-selected.read-write` fix from this same session's
> Phase 6 work already covers persisting a security-scoped bookmark across relaunches. Build succeeds on
> both platforms, full test suite passing including 10 new cases covering the pure due-date math; end-to-end
> manual verification (folder picked, passphrase set, a `.hvbackup` file actually appearing unattended)
> still needs a pass by the user in Xcode, same sandbox-interaction limitation as every other UI-dependent
> feature this session.
>
> **Revision note (2026-07-15):** Phase 12's Scheduled Backup is now gated behind `is_lifetime_unlocked`,
> reversing the day-one ungated decision — the manual "Encrypted Backup"/CSV buttons stay free either way,
> so this doesn't reopen Section 9's "never gate data export" rule, it just gates the automation layer on
> top. See Section 8's gating decision writeup and Phase 12's follow-up entry for the details.
>
> **Revision note (2026-07-15):** Added a **cost-per-wear chart** to Insights (Phase 11 follow-up) —
> `Watch` gained an optional `purchasePrice` and a computed `costPerWear`, and a new
> `CostPerWearChartView.swift` joins the dashboard as a 5th card, already covered by Insights' existing
> paywall. Raw purchase price is shown for free on `WatchDetailView`; the derived cost-per-wear stays
> Insights-exclusive by design. Included in the encrypted backup, deliberately excluded from CSV. Build
> succeeds on both platforms, full test suite passing (40/40).
>
> **Revision note (2026-07-15):** A same-day polish pass, not tied to a new phase number: Phase 7's
> `ServiceContactOverride` and `CustomServiceCenter` gained optional `phone`/`address`/`secondaryWebsite`
> fields (see Phase 7's follow-up entry below — the bundled `OfficialServiceDirectory` data itself is
> unchanged and still deliberately website-only); a shared `SectionHeader.swift` component (centered,
> `.title2.weight(.semibold)`) replaced the platform-default section-header styling app-wide, via the
> `ui-designer` subagent; `VaultGridView`'s toolbar was fixed for iOS 26 Liquid Glass, where the sort control
> and Add button were rendering fused into one pill; a stray Xcode 16 build warning around
> `Info-iOS-BackgroundTasks.plist` (Phase 12) was cleaned up; and the first-launch demo watch was changed
> from a real "Rolex Explorer" to an explicitly fictional "Sample Brand" / "Example Watch" placeholder. No
> schema migration, no new gating, no business logic touched. Full detail in `CLAUDE.md`.

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
| Appearance: light/dark mode override + predetermined accent color theming | Pure local UI preference (`@AppStorage`), no external data | Table stakes — most collection-tracker apps already follow/override system appearance; accent color choice is a low-cost polish item, not a differentiator on its own |
| Insights dashboard (wear frequency, service status, wear-vs-maintenance correlation, collection growth, cost per wear) | Local aggregation/charting of data the user already owns (`WearLog`, `ServiceRecord`, `Watch`) via Swift Charts | Mixed — WatchGrid already ships a stats dashboard (value, brand distribution, see §10), so *having* a dashboard is table stakes; the wear-vs-maintenance correlation chart and the cost-per-wear chart (added 2026-07-15, `Watch.purchasePrice`) weren't seen in any surveyed competitor and are this feature's actual differentiating angle |
| Scheduled automatic encrypted backup (Keychain-stored passphrase, user-picked folder, Daily/Weekly/Monthly) | Local file I/O + local OS scheduling (`BGTaskScheduler`/`NSBackgroundActivityScheduler`), no server | Niche — no surveyed competitor offers hands-off scheduled local backup; existing manual encrypted backup is already table stakes, this just removes the "remembering to do it" step |

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

## 5. Implementation Status (as of 2026-07-15)

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
  mass-market through independent haute horlogerie, website-only contact info by design, user-editable per
  entry via `ServiceContactOverride` with a reset-to-default action — as of 2026-07-15 an override can also
  add a phone number, address, and secondary website, though the bundled defaults themselves stay
  website-only) plus user-added, user-editable `CustomServiceCenter` entries (name, brand, phone, website,
  secondary website, address, notes), browsable/searchable in independently collapsible sections of the
  `ServiceCentersView` sidebar screen.
- **Entitlements + StoreKit 2:** `Entitlements` `@Model` and `PurchaseManager` (StoreKit 2, one
  non-consumable lifetime-unlock product) gate the Insights dashboard and (as of 2026-07-15) Scheduled
  Backup behind `is_lifetime_unlocked` — new-watch creation and manual export/backup stay free regardless;
  see the Phase 8 writeup below for the two manual (non-code) steps still needed before shipping, and
  Section 8's gating writeup for the full gated/ungated split. (Note: several bullets in this 5.1 list —
  Appearance/Phase 10, Insights/Phase 11, Scheduled Backup/Phase 12 — postdate this list's last full
  rewrite on 2026-07-13; see Section 6's Phase entries below for the authoritative, up-to-date detail on
  each.)
- **Learn Hub** (2026-07-15, Phase 13, not originally in this plan): a free/ungated educational section —
  see Section 6's Phase 13 entry for the full writeup.

### 5.2 Gaps against this plan's V1 scope

Phases 1–13 of Section 6 — the entire ordered V1 plan plus the two features added 2026-07-14 (**Phase 10**,
Appearance, and **Phase 11**, the Insights dashboard), **Phase 12** (Scheduled Backup, 2026-07-15), and
**Phase 13** (Learn Hub, 2026-07-15, outside this plan's original scope) — are complete. Nothing remains
against this plan's V1 scope; the only work left in this document is V2 (Section 4's subscription rollout,
Section 10's reordering of it) once V1 has real user traction.

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
- **Bug found and fixed (2026-07-14, while investigating whether export could reach Google Drive/iCloud
  Drive):** the macOS target's App Sandbox entitlement was `ENABLE_USER_SELECTED_FILES = readonly`
  (compiled to `com.apple.security.files.user-selected.read-only`). Apple's own entitlement docs cover
  files picked via *either* an Open or a Save dialog under this same key — with only read-only access
  granted, the CSV export and encrypted backup export `.fileExporter` calls could browse to any save
  location fine but would fail to actually **write** the file once picked, on macOS only (iOS's document
  picker doesn't depend on this entitlement at all). Not specific to cloud destinations — this would have
  failed saving anywhere, including local disk. Fixed by changing the build setting to
  `ENABLE_USER_SELECTED_FILES = readwrite` in both Debug and Release configs; confirmed via
  `codesign -d --entitlements :-` that the compiled entitlement is now
  `com.apple.security.files.user-selected.read-write`, and that both `xcodebuild build` (macOS and iOS
  Simulator) and the full test suite (37/37) still pass. Separately confirmed (from platform documentation,
  not a live click-through): iOS's `.fileExporter` already surfaces both iCloud Drive and Google Drive (if
  installed) as save destinations with no entitlement or code changes needed, since it hands off to the
  system Files picker rather than requiring an app-specific iCloud container.

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
- Added `ServiceCentersView.swift`: a searchable (`.searchable`) List with two independently collapsible
  sections — "Manufacturer Support" and "My Service Centers" — using `DisclosureGroup` rather than a plain
  `Section`, since the full manufacturer list (169 entries) is long enough that collapsing it matters. Both
  sections auto-expand while a search query is active, so a match never ends up hidden behind a collapsed
  group. Search filters both sections by brand or name. A "+" toolbar button opens `AddServiceCenterView`
  in create mode; tapping (or right-clicking/long-pressing for the context menu) a custom entry reopens the
  same sheet in edit mode via a `centerToEdit` param, mirroring `AddWatchView`'s edit pattern.
  - **Follow-up enhancement (2026-07-14):** manufacturer entries were originally read-only. Added a new
    `ServiceContactOverride` `@Model` (keyed by `brand`) so a user can edit a bundled contact's name/
    website/notes at their own discretion — tapping a Manufacturer Support row opens `EditOfficialContactView`
    pre-filled with the current effective values (override if one exists, else the bundled default), and a
    "Reset to Default" action (shown only when an override exists) deletes the override row outright rather
    than storing a synthetic "default" row. `ServiceCentersView` merges `OfficialServiceDirectory.contacts`
    with any matching override into a private `EffectiveOfficialContact` before display, and
    `OfficialServiceContact.id` was changed from a fresh `UUID()` to the `brand` string so row identity
    (and the override lookup keyed on it) stays stable across re-renders.
  - **Follow-up enhancement (2026-07-15):** `ServiceContactOverride` gained optional `phone`, `address`,
    and `secondaryWebsite` fields (it previously only carried `name`/`website`/`notes`), and
    `CustomServiceCenter` (which already had `phone`/`address`) gained `secondaryWebsite` to match. This
    does not reopen the bundled-data design decision above — `OfficialServiceDirectory`'s 169 entries stay
    website-only; the new fields only ever come from a user-entered override, surfaced through
    `EffectiveOfficialContact`'s passthrough computed properties. `EditOfficialContactView` and
    `AddServiceCenterView` both gained matching form fields; `OfficialContactRow`/`CustomCenterRow` display
    them conditionally. Plain additive optionals, no migration.
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
  live App Store Connect record. Originally flagged two manual, non-code steps remaining before shipping:
  (1) in Xcode, Edit Scheme → Run → Options → StoreKit Configuration → select `Configuration.storekit`; (2)
  register the same product ID in App Store Connect for the real listing.
  - **Resolved 2026-07-14 (step 1):** a shared scheme (`xcshareddata/xcschemes/Horology Vault.xcscheme`) is
    now committed with `Configuration.storekit` wired in as its StoreKit Configuration, so this is no longer
    a per-machine setup step — a fresh checkout gets working local purchase testing immediately. Verified by
    running the full purchase flow on both macOS and an iOS Simulator: `Product.products(for:)` resolved the
    test product, `purchase()` completed (after also turning off the config's simulated Ask to Buy, which
    otherwise exercises the `.pending`/parental-approval path on every attempt), and `Entitlements.isLifetimeUnlocked`
    flipped to `true`. Step 2 (App Store Connect registration) remains outstanding — that one can't be done
    from inside the repo.
- Implemented the demo-mode gating this plan specifies: `ContentView` seeds exactly one sample watch (a
  Rolex Explorer) plus an `Entitlements()` row on a truly empty first launch (gated on both `entitlements`
  and `watches` being empty, so an existing user's real collection is never touched), and `VaultGridView`
  originally disabled its "Add Watch" toolbar button and showed a persistent "Unlock Full Version" banner
  whenever `entitlements.first?.isLifetimeUnlocked` is false — no hard paywall on launch. *Scope note:* only
  the Vault's "Add Watch" action was gated, not every "+" button app-wide (Straps/Wishlist/Service
  Centers/etc. stayed open).
  - **Follow-up revision (2026-07-14):** this gating point moved. "Add Watch" is no longer gated at all —
    `VaultGridView`'s `isUnlocked` check, `unlockBanner`, and the `.disabled(!isUnlocked)` on the toolbar
    button were all removed, along with the now-unused `entitlements`/`PurchaseManager` reads in that file.
    `DashboardView` (Insights, Phase 11) is the feature gated behind `is_lifetime_unlocked` now instead —
    see Section 8's revised "Gating decision for V1" for the reasoning. `SettingsView`'s Purchase section
    (below) is unaffected by this change.
- Wired `SettingsView`'s Purchase section to the real `PurchaseManager`: shows "Full Version" vs.
  "Demo (Read-Only)" based on the `Entitlements` row, an "Unlock Full Version — \(price)" button when
  locked, and a working "Restore Purchase" button, plus an inline error line if `purchaseManager.lastError`
  is set.

### Phase 9 — Tests ✅ Done (2026-07-14)
Landed as one batch against the finished V1 feature set rather than incrementally per-phase as originally
suggested, since the earlier phases shipped before this plan's own testing discipline caught up with them.
- **Fit Calculator math:** the fit-check logic (`wristWidthMM`, `overhangMM`, `fits`) was pulled out of
  `FitDiagramView`'s private computed properties — not unit-testable in place, since a SwiftUI View's
  private members aren't visible to a separate test target — into a new pure `FitCalculator.swift`
  (`FitCalculator.evaluate(lugToLugMM:wristTopWidthCM:) -> Result`). `FitDiagramView` now just calls it via
  one `fitResult` computed property; rendering behavior is unchanged. `FitCalculatorTests.swift` covers the
  exact-fit boundary, watch-smaller-than-wrist, watch-larger-than-wrist (verifying overhang amount), and
  zero/negative edge cases.
- **Entitlements/PurchaseManager gating logic:** `PurchaseManager`'s insert-or-update persistence logic was
  extracted from the private `reconcileEntitlements()` into `static func updateEntitlementsRecord(unlocked:in:now:)`
  — callable directly against an in-memory `ModelContext` without touching StoreKit, so the part that
  actually decides whether the paid feature set is unlocked can be tested in isolation. Live StoreKit calls
  (`Product.products(for:)`, `Transaction.currentEntitlements`, `product.purchase()`) aren't meaningfully
  unit-testable without Apple's `StoreKitTest`/`SKTestSession` — `EntitlementsTests.swift` covers the
  reconciliation/gating logic that's actually reachable (insert-vs-update-in-place with no duplicate rows,
  locking on revoke/refund, the UI's `entitlements.first?.isLifetimeUnlocked ?? false` read before/after a
  simulated purchase, `SubscriptionStatus` round-tripping, `configure(modelContext:)` idempotency);
  full end-to-end purchase-flow testing via `SKTestSession(configurationFileNamed: "Configuration")` against
  the existing `Configuration.storekit` is a reasonable fast-follow, not done here.
- **Model invariants:** `WatchModelTests.swift` covers `Watch.serviceDueDate`/`isServiceDue` (fallback to
  `acquisitionDate`, most-recent `ServiceRecord`, the 3-year boundary, the due clock resetting after a new
  service), cascade-delete of `ServiceRecord`/`WearLog`/`ProvenanceDoc` (individually and together), and
  nullify-not-delete of an attached `Strap` on watch deletion — all against an in-memory `ModelContainer`.
- 33 tests total (32 new + the original Xcode-scaffold `example()` case), all passing via
  `xcodebuild -project "Horology Vault.xcodeproj" -scheme "Horology Vault" -destination 'platform=macOS' test`.
  No production bugs were found in the process — only a mistake in one test's own chosen input values,
  caught and fixed by actually running the suite rather than assuming it would pass.

### Phase 10 — Appearance: light/dark mode + accent color ✅ Done (2026-07-14)
No schema change and no new `@Model` — this is pure device-local UI preference, same reasoning already
used for why Settings' wrist profile lives in `UserProfile` but a display preference like this doesn't need
to be a SwiftData row at all: `@AppStorage` is the right tool since nothing here needs to be queried,
synced, or included in the encrypted backup.

- Added `ColorSchemePreference: String, CaseIterable` (`system`, `light`, `dark`, each with a `label` and a
  `colorScheme: ColorScheme?`) and `AccentColorOption: String, CaseIterable` (`blue` default, plus `red`,
  `orange`, `yellow`, `green`, `teal`, `purple`, `pink`, each with a computed `color: Color`) directly in
  `SettingsView.swift`.
- The selections are stored as `@AppStorage("colorSchemePreference")` / `@AppStorage("accentColorOption")`
  (SwiftUI's native `RawRepresentable`-where-`RawValue == String` support, so no manual raw-string
  wrangling), read in both `SettingsView` (to drive the pickers) and `ContentView` (to apply them).
  `ContentView.body` applies `.tint(accentColorOption.color)` and
  `.preferredColorScheme(colorSchemePreference.colorScheme)` once on the root `NavigationSplitView`, so
  every screen — including sheets presented from within it — inherits both without per-view changes.
- Added an "Appearance" `Section` to `SettingsView`, positioned first (above Wrist Profile) — a segmented
  `Picker` (labels hidden, since the section header already says "Appearance") for the color scheme, and a
  row of tappable circular `AccentColorSwatch` views for the accent (checkmark overlay on the selection),
  mirroring the Reminders/Notes accent-color-grid pattern.
- No test coverage added — this phase has no business logic to extract (unlike Phase 9's rationale for
  pulling fit-check math or entitlement reconciliation into testable functions), just enum→`Color`/
  enum→`ColorScheme?` mappings and view wiring. Verified via a successful `xcodebuild build`, the full
  `xcodebuild test` suite (33/33 passing, no regressions), and — since the sandbox this phase was
  implemented in has no Screen Recording/Apple Events permission to drive or screenshot a GUI app — a manual
  pass run by the user directly in Xcode (Cmd+R), confirming the scheme picker overrides light/dark and
  each accent swatch re-tints the UI.

### Phase 11 — Insights dashboard (wear frequency, service status, wear-vs-maintenance trends) ✅ Done (2026-07-14)
Sequenced after Phase 10 so the new charts pick up the user's accent color via the app-wide `.tint(_:)` for
free.

- Added a 7th sidebar entry, **Insights**, to `ContentView.Section` — inserted between Vault and Fit
  Calculator. Deliberately named **Insights**, not "Dashboard" (the file is still `DashboardView.swift`,
  same "filename doesn't have to match the sidebar label" precedent as `VaultGridView`) — Section 1's table
  already calls the Vault itself "the dashboard/collection grid," so reusing that word for a second screen
  would be confusing.
- Added `Watch.wearCountSinceLastService: Int` to `Watch.swift` — counts `wearLogs` where
  `dateWorn > (lastServiceDate ?? acquisitionDate)`. The only data-model change either phase needed;
  everything else derives from relationships that already existed. Covered by four new cases in
  `WatchModelTests.swift` (zero wear logs, wear entirely before service, wear split across the service
  boundary, and the no-service-records fallback to `acquisitionDate`) — 37 tests total now, all passing.
- Added `DashboardView.swift`: a `ScrollView` of four titled `InsightCard`s (a private helper view,
  `.thinMaterial` background matching `VaultGridView`'s existing card styling), each wrapping one
  single-purpose chart view — matching the `AccuracyChartView.swift` precedent (one file, one `Chart`, one
  `ContentUnavailableView` empty state) rather than one large file with several `Chart`s inline:
  - `WearFrequencyChartView.swift` — horizontal `BarMark` (watch name on the category axis) of wear-log
    count per watch, sorted descending. Empty state when no watch has any `WearLog` entries yet.
  - `ServiceStatusChartView.swift` — horizontal `BarMark` of days until/past each watch's `serviceDueDate`,
    colored red when overdue, green otherwise (an intentional exception to inheriting the accent tint —
    status color here is meaningful, not decorative).
  - `WearServiceCorrelationChartView.swift` — a `PointMark` scatter of `wearCountSinceLastService` against
    days elapsed since the last service, one point per watch (annotated with brand/model), surfacing
    watches getting heavy wear without a recent service. This is the chart Section 1's table row calls out
    as the actual differentiator, not just a stats readout.
  - `CollectionGrowthChartView.swift` — `LineMark` (step interpolation) of cumulative watch count by
    `acquisitionDate`.
- **Follow-up revision (2026-07-14, same day as Phase 8's):** `DashboardView` became the feature gated
  behind `is_lifetime_unlocked` when "Add Watch" gating was removed from `VaultGridView` — see Section 8's
  revised "Gating decision for V1." When locked, the entire screen (not just an individual action) shows a
  `ContentUnavailableView`-based paywall via a new `lockedView` computed property (lock icon, description,
  "Unlock Full Version — \(price)" button calling `purchaseManager.purchase()`), taking priority over the
  existing empty-collection state. Required adding `@Query private var entitlements: [Entitlements]` and
  `@Environment(PurchaseManager.self) private var purchaseManager` to `DashboardView`, plus a `StoreKit`
  import for `Product.displayPrice`.
- The four chart views themselves aren't unit-tested (SwiftUI `Chart` rendering isn't meaningfully testable
  outside snapshot testing, which this project doesn't use anywhere else); verified via a successful
  `xcodebuild build` and — same sandbox screen-access limitation noted in Phase 10 — a manual pass run by
  the user directly in Xcode, confirming the Insights tab and all four charts render correctly against
  their real collection.
- **Follow-up enhancement (2026-07-15): cost-per-wear, a 5th chart.** Added while brainstorming what else
  could justify Insights' premium price — no surveyed competitor tracks this, and it's a metric collectors
  care about (a watch's cost-per-wear drops as it gets used more, which is how collectors justify expensive
  purchases to themselves). Needed a real schema addition, unlike the original four charts: `Watch` gained
  `purchasePrice: Double?` (optional, no validation requirement, defaulted to `nil` in `init` so no
  existing call site broke) and a computed `costPerWear: Double?` (`nil` unless both `purchasePrice` is set
  *and* `wearLogs` is non-empty, avoiding a divide-by-zero and avoiding implying "$0/wear" for an unworn
  watch) — covered by 3 new cases in `WatchModelTests.swift` (40 tests total now, all passing). Two product
  decisions were confirmed directly with the user rather than assumed, both aimed at keeping this feature
  worth its premium framing rather than diluting it: (1) the raw `purchasePrice` is shown for free on
  `WatchDetailView`'s Overview section (it's just data the user entered), but the derived `costPerWear` is
  deliberately **not** shown there — it stays exclusive to the paywalled `CostPerWearChartView.swift`
  (modeled directly on `WearFrequencyChartView.swift`'s shape: `let watches: [Watch]`, a private sorted
  tuple array, `ContentUnavailableView` empty state, horizontal `BarMark` at `.frame(height: 220)`), sorted
  cheapest-first as a "best value" leaderboard, same positive framing as the wear-frequency chart; (2)
  `purchasePrice` round-trips through the encrypted backup (`WatchBackup` struct + both
  `exportEncryptedBackup`/`importEncryptedBackup`) but is **deliberately excluded from CSV export/import**
  — CSV is meant for portability and travels as plaintext wherever it's saved (cloud drives, sharing),
  a meaningfully different exposure than data that only ever leaves the device encrypted; a comment was
  left at `DataBackupManager`'s CSV functions so a future session doesn't "fix" the apparent gap. No new
  gating code was needed — the chart lives inside `DashboardView`, already fully gated, so it just became a
  5th card; entering a purchase price itself stays free everywhere, consistent with never gating a user's
  own data entry, only the derived insight. Verified via `xcodebuild build` (both platforms) and
  `xcodebuild test` (full suite green); the actual chart rendering hasn't been manually eyeballed yet, same
  outstanding verification gap as the rest of this phase and Phase 12.

### Phase 12 — Scheduled automatic encrypted backup ✅ Done (2026-07-15)
The existing manual "Encrypted Backup" button (Phase 6) only runs when the user remembers to tap it — this
phase automates it: fully silent, no user interaction once configured, reusing the same encrypted
`.hvbackup` format rather than switching to CSV, since the user explicitly chose full-collection coverage
over the simpler-but-partial CSV path.

- Added `Horology Vault/KeychainHelper.swift`: a static-only enum (matching `NotificationManager`/
  `DataBackupManager`'s style) storing the scheduled-backup passphrase in the Keychain
  (`kSecClassGenericPassword`, `service` = bundle identifier, `account` = a fixed constant) —
  `savePassphrase`/`readPassphrase`/`deletePassphrase`. `savePassphrase` tries `SecItemUpdate` first,
  falling back to `SecItemAdd` on `errSecItemNotFound`, so changing the passphrase doesn't need a separate
  delete step. There was no Keychain code anywhere in this project before this phase.
- Added `Horology Vault/ScheduledBackupManager.swift`: another static-only enum, owning:
  - `BackupFrequency` (`daily`/`weekly`/`monthly`) — lives here rather than in `SettingsView.swift`, unlike
    `ColorSchemePreference`/`AccentColorOption`, because it has a real logic owner (matches how
    `SubscriptionStatus` lives in `Entitlements.swift`, not in the view that displays it).
  - `isBackupDue(frequency:lastRunDate:now:calendar:) -> Bool` — the pure, testable due-date math, using
    `calendar.date(byAdding:)` rather than a flat day count so "Monthly" tracks a calendar month instead of
    a hardcoded 30 days. `now`/`calendar` are injected parameters, same testability pattern as
    `PurchaseManager.updateEntitlementsRecord(unlocked:in:now:)`.
  - `resolveBookmarkedFolderURL`/`createFolderBookmark` — security-scoped bookmark handling for the
    user-picked destination folder, with a real macOS/iOS split: macOS needs `.withSecurityScope` on both
    creation and resolution (that option doesn't exist on iOS, where document-picker URLs are implicitly
    security-scoped). This is the first persisted (cross-launch) security-scoped bookmark anywhere in this
    project — the four pre-existing `.fileImporter` usages were all transient, single-file picks.
  - `performBackupIfDue(context:now:)` — the orchestration: reads settings from `UserDefaults.standard`
    directly rather than `@AppStorage` (a static enum can't hold property wrappers), checks `isBackupDue`,
    resolves the bookmark, `startAccessingSecurityScopedResource()`, reads the Keychain passphrase, calls
    the existing `DataBackupManager.exportEncryptedBackup(context:passphrase:)` unchanged, writes
    `HorologyVaultBackup-<yyyy-MM-dd>.hvbackup` into the folder. **Only updates the last-run timestamp on
    full success** — a missing passphrase, unresolvable bookmark, or write failure leaves the due-check
    retriable next time rather than marking a failed cycle as done.
  - `#if os(iOS) registerBackgroundTask`/`scheduleNextBackgroundTask` — `BGProcessingTask`
    (`requiresNetworkConnectivity = false`, `requiresExternalPower = false`), re-submitted after every
    launch registration and every run since BGTaskScheduler requests are one-shot, not naturally recurring.
  - `#if os(macOS) startBackgroundActivityScheduler` — `NSBackgroundActivityScheduler`, hourly, since the
    user confirmed macOS only needs to run while the app is alive (foreground or background) — explicitly
    no LaunchAgent/SMAppService helper, ruled out as unnecessary complexity for this app.
  - This is the **first** `#if os(...)` branching this scheduling area needs — `NotificationManager` has
    zero platform branches since `UNUserNotificationCenter` is already unified; `BGTaskScheduler` vs.
    `NSBackgroundActivityScheduler` are fundamentally different APIs with no shared abstraction worth
    building for two call sites.
- **Launch-time catch-up**: since `BGTaskScheduler` is opportunistic (the OS decides when it actually
  fires, can skip days), `ContentView`'s existing `.task` also calls
  `ScheduledBackupManager.performBackupIfDue(context:)` directly on every launch, in addition to registering
  the periodic schedulers — otherwise "automatic" could silently mean weeks with no backup on iOS if the
  app isn't used regularly. Confirmed with the user as a deliberate choice, not an oversight.
- **Free/ungated at launch**, consistent with Section 9's existing decision that data export/backup should
  never be gated — this is the same feature, just automated. Confirmed with the user rather than assumed.
  **Reversed 2026-07-15** — see the follow-up entry below and Section 8's gating decision writeup.
- `Horology_Vault_App.swift` gained an explicit `init()` (there was none before) calling
  `ScheduledBackupManager.registerBackgroundTask(container:)` under `#if os(iOS)` — `BGTaskScheduler`
  registration is documented by Apple to silently fail if it happens any later than this (e.g. from a
  `View.task`, which is how every other piece of launch-time setup in this app works). Swift's
  initialization order guarantees `sharedModelContainer`'s existing stored-property initializer still runs
  before this `init()` body executes, so referencing it directly here is safe.
- `SettingsView.swift` gained a new "Scheduled Backup" section (inserted after the existing "Data" section):
  an enable/disable `Toggle`, a "Backup Folder" row with a picker button (a **new, isolated-anchor**
  `.fileImporter` with `allowedContentTypes: [.folder]`, its own `.background { EmptyView().fileImporter(...) }`
  block — not stacked alongside the four pre-existing exporters/importers, per the modifier-collision bug
  already hit and fixed once in this same file this session), a `Frequency` picker, and passphrase
  setup/change reusing the existing `PassphrasePurpose` alert flow via a new `.settingScheduledBackupPassphrase`
  case (writes to `KeychainHelper` instead of exporting), plus a "Remove Stored Passphrase" action shown only
  when one is currently stored. Disabling the toggle does **not** delete the stored passphrase, so
  re-enabling doesn't force re-entry.
- Two platform-configuration unknowns were resolved empirically, not assumed, before writing feature code:
  - **iOS**: `BGTaskSchedulerPermittedIdentifiers` (a custom string array) and `UIBackgroundModes`
    (`processing`) don't synthesize via `INFOPLIST_KEY_*` build settings the way this project's other
    Info.plist keys (scene manifest, orientations) do — those keys were silently dropped from the compiled
    plist when tried. Fixed by adding a small supplemental `Horology Vault/Info-iOS-BackgroundTasks.plist`
    and pointing `"INFOPLIST_FILE[sdk=iphoneos*]"`/`"INFOPLIST_FILE[sdk=iphonesimulator*]"` at it —
    confirmed via `PlistBuddy` that Xcode merges this with the still-`GENERATE_INFOPLIST_FILE`-synthesized
    content rather than replacing it (both the new custom keys and the pre-existing synthesized ones, e.g.
    `CFBundleIdentifier`, showed up correctly in the compiled `Info.plist`). Scoped to iOS SDKs only via the
    same `[sdk=...]` qualifier pattern already used elsewhere in this target; confirmed the macOS build is
    unaffected.
  - **macOS**: persisting a security-scoped bookmark across app relaunches needs
    `com.apple.security.files.user-selected.read-write` — confirmed via `codesign -d --entitlements :-`
    that this project already has it, from this session's earlier Phase 6 sandbox-entitlement fix
    (`ENABLE_USER_SELECTED_FILES = readwrite`). No new `.entitlements` file was needed.
- Test coverage: `Horology VaultTests/ScheduledBackupManagerTests.swift` covers only `isBackupDue` (never
  run before → always due for all three frequencies; run one hour ago → not due for all three; a
  just-over/just-under boundary pair for each of Daily/Weekly/Monthly; an exactly-on-the-boundary case) —
  10 cases total, all passing. Deliberately does **not** attempt to test `BGTaskScheduler`,
  `NSBackgroundActivityScheduler`, Keychain, or real file I/O, matching this project's established
  precedent (same reasoning already applied to StoreKit's live system calls).
- Verified via `xcodebuild build` on both macOS and iOS Simulator, `xcodebuild test` (full suite green,
  including the 10 new cases), and the two empirical platform-configuration checks above. **Not yet
  manually verified end-to-end** (enable the feature, pick a folder, set a passphrase, force a due backup,
  confirm a `.hvbackup` file actually appears with no further interaction) — this sandbox can't drive that
  live interaction, same limitation noted for every UI-dependent feature this session; needs a pass by the
  user in Xcode.
- **Follow-up revision (2026-07-15): gated behind `is_lifetime_unlocked`.** Reverses the launch-day ungated
  decision above — see Section 8's gating decision writeup for why this doesn't reopen the "never gate data
  export/backup" rule (manual export/backup stays free regardless; this only gates the automation layer).
  `SettingsView.scheduledBackupSection` became `@ViewBuilder`, branching on the same `isUnlocked` computed
  property `purchaseStatusSection` already reads: unlocked shows the existing toggle/folder/frequency/
  passphrase controls unchanged, locked shows a compact in-section paywall row (lock icon, description,
  "Unlock Full Version — \(price)" button) rather than `DashboardView`'s full-screen `ContentUnavailableView`
  treatment, since this is one Section within a multi-section Settings `Form`, not a standalone screen.
  `ScheduledBackupManager.performBackupIfDue` also gained its own entitlement check — fetches
  `Entitlements` directly from the passed-in `ModelContext` (`(try? context.fetch(FetchDescriptor<Entitlements>()))?.first?.isLifetimeUnlocked`,
  since a static enum has no `@Query`) and bails before touching `UserDefaults`/Keychain/the bookmark if
  locked — so a background run can't slip through for a user whose entitlement lapses after they'd already
  configured and enabled the feature. Verified via `xcodebuild build` (both platforms) and `xcodebuild test`
  (full suite still green); the locked-state UI itself hasn't been manually eyeballed yet, same outstanding
  verification gap as the rest of this phase.

### Phase 13 — Learn Hub (horology education content) ✅ Done (2026-07-15)
Not originally scoped in this plan — added from user research into what would help horology beginners
(complications, watch anatomy, materials, maintenance, etc.), with the implementation shape settled via
three explicit decisions before writing code: **static Swift data** (not JSON/remote-fetched) since the
content is small and bundled-with-the-app is simpler than a fetch/cache layer; **broad overview across many
categories** rather than narrow-deep on a handful, since a beginner audience benefits more from coverage
than depth; and **cross-linking back into the user's own Vault** (e.g. tapping "Chronograph" shows the
user's own watches with that complication) so the educational content ties into the collection they're
already building, rather than sitting in an isolated silo.

- An Explore-agent codebase survey preceded planning and shaped it: the app is sidebar/`NavigationSplitView`-
  driven, not `TabView`; `Watch.complications` is a free-form `[String]` with its only canonical vocabulary
  living in a private array inside `AddWatchView.swift`; `OfficialServiceDirectory.swift` was the
  established precedent for bundled static reference data (plain `Identifiable` struct + `static let [...]`
  literal, not a `@Model`).
- **Free/ungated.** Unlike every other phase in this section, this isn't a monetization decision at all —
  Learn Hub is onboarding/retention content, not something that belongs behind `is_lifetime_unlocked`.
- Extracted `commonComplications` out of `AddWatchView.swift` into `Watch.swift` as
  `static let commonComplications`, updating `AddWatchView.swift` to reference it — so the Add Watch
  complications picker and Learn Hub's cross-link share one source of truth instead of two lists that
  could silently drift apart.
- Added `Horology Vault/LearnHubContent.swift`: `LearnCategory` (8 cases: Watch Anatomy, Movements,
  Complications, Materials & Case, Straps & Bracelets, Care & Maintenance, Buying & Ownership, Glossary),
  `LearnTopic` (slug/category/title/summary/body/optional `complicationName` for the Vault cross-link/
  optional `systemImage`), and `LearnHubContent.topics` — 50 hand-written static articles.
- Added `Horology Vault/LearnHubView.swift`: a category-grouped, `.searchable` list pushing into a detail
  view; the detail view shows an `InYourVaultCard` (via `@Query`) when the topic's `complicationName`
  matches watches the user actually owns, navigating into the existing `WatchDetailView`.
- Wired a new `.learnHub` case into `ContentView.Section` (icon `book.closed`), placed right after Vault.
- Added `Horology VaultTests/LearnHubContentTests.swift`: asserts `LearnTopic.slug` uniqueness and that
  `complicationName` values round-trip exactly against `Watch.commonComplications` in both directions —
  guards the cross-link from silently breaking if either list drifts.
- Verified via `xcodebuild build`/`xcodebuild test` on macOS (project uses Xcode's synchronized
  file-system groups, so new files needed no manual `.pbxproj` editing).
- **UI design pass:** the user explicitly invoked the `ui-designer` subagent to review the shipped UI and
  brainstorm improvements. It built a throwaway, type-checked-only SwiftUI prototype at a scratchpad path
  (no visual Canvas/Simulator capture available in this sandbox) without touching production files, and
  proposed a prioritized list. The top 3 were implemented same-session:
  1. **Per-topic SF Symbols** instead of one icon reused per whole category — added `systemImage: String?`
     to `LearnTopic` plus a `displaySystemImage` fallback to the category icon, hand-assigned across all
     50 topics.
  2. **Typography overhaul** on the detail screen — `.largeTitle` title, `.title3` deck-style summary, a
     tinted `CategoryChip` capsule, `.lineSpacing(4)` body text, `.frame(maxWidth: 700)` centered, since
     paragraphs were stretching edge-to-edge unreadably on macOS/iPad.
  3. **`InYourVaultCard`** replacing the plain-text cross-link footnote — a tinted, bordered card with a
     star icon, ownership count, and rows with a real 44pt `WatchThumbnail` photo (a small local
     `UIImage`/`NSImage` decode written directly in `LearnHubView.swift` — deliberately not reusing
     `WatchCardView`'s Vision-based smart-crop pipeline, which is overkill for a tiny list thumbnail) plus
     a chevron.
  Also added as a small bonus polish item: `ContentUnavailableView.search(text:)` empty state when Learn
  Hub search finds nothing, matching the pattern already used in `VaultGridView`/`DashboardView`/
  `MaintenanceView`.
  - One real bug surfaced along the way: making `WatchCardView.swift`'s private `platformImage(from:)`
    non-private (to reuse it for `WatchThumbnail`) collided with an unrelated identically-named private
    function already in `AddWatchView.swift` — a Swift redeclaration error, since making one internal
    exposed it module-wide. Reverted `WatchCardView.swift` back to `private` and wrote a small
    self-contained image-decode computed property directly inside `LearnHubView.swift` instead.
  - Verified again via `xcodebuild build`/`xcodebuild test` — full suite green, including
    `LearnHubContentTests`.
- **Bug found post-ship, fixed same day:** the user reported the Titanium topic (Materials & Case) showed
  no visible icon. Root cause: it was assigned the SF Symbol name `"feather"`, which does not actually
  exist — `Image(systemName:)` fails silently at runtime for an unrecognized name, so a clean
  `xcodebuild build` says nothing about whether a systemName string resolves to a real symbol. Diagnosed
  with a standalone Swift script calling `NSImage(systemSymbolName:accessibilityDescription:)` for every
  `systemImage` string in `LearnHubContent.swift` and checking which returned `nil` — confirmed `feather`
  was the only invalid one across all 50 topics. Fixed by switching Titanium to `"scalemass"` (fits the
  article's content — titanium being lighter than steel). **Takeaway for future SF Symbol use anywhere in
  this project: verify a symbol name resolves before trusting it — a successful build is not proof the
  icon exists.**
- Not yet manually verified by eye in Xcode's Canvas/Simulator from inside any session (same sandbox
  limitation — no Screen Recording/Apple Events permission — documented for Phases 10–12); the user should
  do a final visual pass in Xcode. Remaining `ui-designer` brainstorm ideas not built: a category-grid
  landing screen (replacing the flat list), tappable related-topic footer links (articles already
  cross-reference each other in prose but aren't linked yet), a Watch Anatomy interactive diagram, a
  movements comparison table, and `@AppStorage`-backed read/progress tracking.

## 7. SwiftUI View Hierarchy (V1)

Root: a single `NavigationSplitView` — renders as a sidebar + content + detail 3-column layout on macOS/iPad, and collapses to a stack on iPhone. This is the standard SwiftUI pattern for one codebase that adapts to both platforms.

**Sidebar (top-level sections):**
- Vault (default/home)
- Insights
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

**Insights**
- `DashboardView` — scrollable set of chart cards: wear frequency per watch, service status (days until/
  past due), wear-vs-maintenance correlation (wear count since last service vs. days since last service —
  flags watches getting heavy use without upkeep), and cumulative collection growth over time. All Swift
  Charts, all derived from data the app already collects — no new backend, no new schema beyond one computed
  property on `Watch`.

**Fit Calculator** (reachable standalone, or from a Workbench)
- `FitCalculatorView` — pick a watch, renders a 2D top-down diagram (SwiftUI `Canvas`) comparing `lug_to_lug_mm` against `wrist_top_width_cm`.

**Wishlist**
- Simple list view; each row has brand/model/target price/notes. *(Price-alert toggle exists in the row UI but is disabled/grayed out until V2.)*

**Maintenance**
- Cross-collection list of upcoming/overdue service items, sorted by due date — this is what drives the local notification reminders, so the screen and the notification scheduling share one query.

**Service Centers**
- Searchable list, in two independently collapsible sections: official manufacturer service/support
  contacts (bundled, editable per entry with a reset-to-default) and user-added custom entries (name,
  brand, phone, website, address, notes), with add/edit/delete for the custom ones.

**Settings**
- Appearance: color scheme override (System/Light/Dark) and a predetermined accent color picker (blue
  default, plus red/orange/yellow/green/teal/purple/pink).
- Wrist profile (`wrist_top_width_cm`, `wrist_side_depth_cm`).
- Data: CSV import/export, encrypted local backup/restore.
- Scheduled Backup: enable/disable toggle, backup folder picker, Daily/Weekly/Monthly frequency, Keychain
  passphrase setup/change/remove — automates the Data section's manual encrypted backup on a schedule.
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

**Known benign console warning (macOS, confirmed 2026-07-14):** calling `product.purchase()` on macOS logs
`Adding 'NSRemoteView' as a subview of NSHostingController.view is not supported and may result in a broken
view hierarchy...` to the console. This is a known SwiftUI/AppKit interop quirk — StoreKit 2's native
purchase-confirmation sheet attaches to a window whose content is a pure SwiftUI `NSHostingView` (exactly
what `WindowGroup { ContentView() }` produces), which macOS doesn't officially support, but it's cosmetic:
the confirmation dialog still appears and the purchase still completes normally. Not caused by anything in
this app's code, not tied to the Phase 6 sandbox-entitlement fix, and not worth chasing a workaround for
unless it starts actually blocking the flow.

**Gating decision for V1 (revised 2026-07-14):** rather than a hard paywall on first launch, let the app
open with the Vault, Fit Calculator, and every other one-time-purchase feature fully usable — including
adding watches — with no lifetime-unlock check at all on that path. The original design disabled "Add
Watch" until purchase; that was reversed because blocking the core "build your own collection" loop turned
out to cost more in onboarding friction than it gained in urgency, and because it left the plan's own
differentiator (Fit Calculator) effectively hidden behind the same wall it was supposed to help sell past.
Instead, **Insights** (the wear/service/maintenance trend dashboard, Section 6 Phase 11) is the feature
gated behind `is_lifetime_unlocked`: it's a "grows with your collection" analytics layer rather than
something a first-time browser needs in order to evaluate the app, and hiding it doesn't block anyone from
experiencing the Vault or Fit Calculator. When Insights is opened locked, it shows a `ContentUnavailableView`
paywall (title, description, and an "Unlock Full Version — \(price)" button) in place of the charts —
never a disabled entry point or a silently broken screen, matching Section 2.3's rule that a gated screen
should always explain itself rather than fail quietly. Maintenance reminders and Provenance/document
storage were considered as additional candidates for gating (both are "matters more to invested collectors
than first-time browsers" features, same reasoning as Insights) but were left open for now — see Section 9.

**(Added 2026-07-15)** **Scheduled Backup** (Section 6 Phase 12) joined Insights as gated behind
`is_lifetime_unlocked`, reversing Phase 12's original ungated launch decision. This doesn't reopen the
"never gate data export/backup" rule above — the manual "Encrypted Backup" and CSV export/import buttons in
the Data section stay completely free either way, so a locked user's own data is never inaccessible.
Scheduled Backup is purely the hands-off automation layered on top of that always-available manual path,
same "convenience feature, not access to your own data" category as Insights. `SettingsView`'s "Scheduled
Backup" section shows a locked-state row (lock icon, description, "Unlock Full Version — \(price)" button)
in place of the toggle/folder/frequency/passphrase controls when locked; `ScheduledBackupManager.performBackupIfDue`
also checks `Entitlements.isLifetimeUnlocked` directly (fetched from the passed-in `ModelContext`, since a
static enum has no `@Query`) before doing anything, not just the UI — so a background run can't slip
through for a user whose entitlement lapses (e.g. a refund) after they'd already configured and enabled it.

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
- **(Added 2026-07-14, from Phase 10)** Whether the 8 predetermined accent colors are the final set, or
  whether a custom color picker should be offered later — 8 was chosen to match the common
  "small fixed palette" pattern (Reminders, Notes) rather than open-ended choice, which also keeps every
  color legible against both light and dark backgrounds without per-color contrast testing.
- **(Added 2026-07-14, from Phase 11)** Whether Insights charts need a time-range filter (e.g. "last year"
  vs. "all time") once collections and wear-log history grow large enough that "all time" gets visually
  noisy — not needed for an initial collection size, worth revisiting once real usage data exists.
- **(Added 2026-07-14, from the gating revision)** Whether Insights alone is enough gated surface to drive
  conversion, or whether **Maintenance reminders** and/or **Provenance/document storage** should join it —
  both were floated as candidates (same "matters more to invested collectors than first-time browsers"
  reasoning as Insights) but left open in this pass. Explicitly ruled out: gating **data export/backup**,
  since restricting a user's ability to get their own data out reads as hostile rather than as a value-add,
  regardless of its conversion potential.
- **(Added 2026-07-15, possible add-on, not scoped as a phase)** A third export format — plain,
  **unencrypted, user-editable JSON** covering the full collection graph (same shape `DataBackupManager`
  already uses internally for the encrypted backup: `BackupPayload`/`WatchBackup`/`StrapBackup`/etc.) — sits
  between today's two options: CSV only covers the flat watch list, and the encrypted backup covers
  everything but is deliberately opaque (AES-sealed, meant as a restore point, not something to hand-edit).
  Real challenges identified if this gets picked up, not just "skip the `encrypt()` call":
  - `WatchBackup.photoData`/`ProvenanceDocBackup.fileData` are raw `Data`, which JSON-encodes as inline
    base64 — makes the file much less human-editable than the pitch implies, since the fields someone would
    actually want to tweak get buried under blob noise.
  - `StrapBackup.attachedWatchIndex: Int?` links a strap to a watch by its *array position* in the JSON,
    not a stable ID — fine for a machine round-trip, silently wrong (or silently dropped, per the existing
    `insertedWatches.indices.contains(index)` guard) if a person reorders/adds/removes a watch entry by
    hand. Would need a real ID-based reference instead of positional linking.
  - `Decodable` failures are all-or-nothing today (one bad field fails the whole file), unlike CSV import's
    existing skip-and-report-invalid-rows behavior — a hand-edited file is far likelier to have one small
    mistake than to be entirely wrong, so this would need the same per-entry-recovery treatment CSV already
    has, plus surfacing `DecodingError`'s `codingPath` instead of a generic "corrupt file" message.
  - No business-rule validation exists beyond shape-checking (a negative `caseDiameterMM` or nonsense date
    would decode fine today) — currently harmless since only the app itself ever produces this payload, but
    not once a human can type into it directly.
  - Would also want a `schemaVersion` field so future format changes don't silently corrupt older
    hand-saved exports.
  Rough sizing: more than a quick add, but not a big rewrite either — closer to a half-day feature once
  properly scoped. Not queued as a numbered phase; revisit if a user actually asks for bulk-editable export.
- **(Added 2026-07-15, from Phase 12; gating choice reversed same day, see Section 8)** Confirmed choices
  for Scheduled Backup, recorded so future sessions don't re-litigate them: gated behind `is_lifetime_unlocked`
  (reversed from the original ungated launch decision — manual export/backup stays free regardless, this
  is just the automation layer); launch-time catch-up runs in addition to the periodic OS schedulers (iOS's
  `BGTaskScheduler` is opportunistic enough that periodic-only could mean silent multi-week gaps); Weekly
  default frequency; the Keychain-stored passphrase survives disabling the toggle (an explicit "Remove
  Stored Passphrase" action exists for anyone who wants it gone specifically, rather than deleting
  automatically on disable).
- **(Added 2026-07-15, from Phase 12)** Whether the `NSBackgroundActivityScheduler`'s hourly check interval
  is fine as a fixed constant or should scale with the chosen frequency (e.g. a Monthly-only user doesn't
  need an hourly wake-up) — left as a flat hourly poll for now since `performBackupIfDue`'s own due-check is
  cheap and the actual enforcement of frequency happens there, not in the poll interval; revisit only if
  the poll frequency itself turns out to have a real battery/CPU cost worth trimming.
- **(Added 2026-07-15, from the cost-per-wear enhancement)** Confirmed choices, recorded so future sessions
  don't re-litigate them: raw `purchasePrice` shown for free on `WatchDetailView`, derived `costPerWear`
  kept Insights-exclusive (the whole point of adding this was to make Insights worth paying for); purchase
  price included in the encrypted backup but excluded from CSV export/import (CSV travels as plaintext
  wherever it's saved, a different exposure than encrypted-only data); single-currency V1 scope via
  `Locale.current`, no per-watch currency selection or historical exchange-rate conversion — revisit only
  if a user with a genuinely multi-currency collection actually asks for it.

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
