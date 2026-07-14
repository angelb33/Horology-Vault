# Session Log

## 2026-07-14 — Session 2

### Accomplished this session

- Implemented Phase 6 of the monetization plan's Section 6 ordered plan: **Data import/export & encrypted
  backup**, wiring up the four previously no-op buttons in `SettingsView`'s Data section.
- Added `Horology Vault/DataBackupManager.swift` (447 lines), a static-only enum with two feature areas:
  - **CSV export/import** (`exportWatchesCSV`/`importWatchesCSV`) covering only `Watch`'s own fields (brand,
    model, reference number, complications, case diameter, lug-to-lug, lug width, acquisition date) — nested
    relations (straps/service/wear/provenance) don't fit a flat row, so they're left to the backup path.
    Uses a small hand-rolled RFC4180-ish CSV encoder (`csvEscape`) and a manual character-by-character
    parser (`parseCSV`) rather than a third-party dependency.
  - **Encrypted full-collection backup/restore** (`exportEncryptedBackup`/`importEncryptedBackup`): builds/
    consumes a private `Codable` `BackupPayload` (watches with embedded service records/wear logs/
    provenance docs, straps linked back to their watch by array index within the same payload since a fresh
    restore has no persistent IDs yet, wishlist items, and the wrist profile), JSON-encoded (ISO8601 dates)
    and sealed with CryptoKit `AES.GCM` using a key derived via `SymmetricKey(data: SHA256.hash(data:))`
    from a user-entered passphrase — no PBKDF2/salt, a deliberate choice documented in a code comment as
    sufficient to deter casual access to a local file without adding complexity beyond what a V1 local
    backup needs.
  - Restore is **additive**: records are inserted alongside whatever's already in the `ModelContext` rather
    than replacing the collection outright, to avoid a silent full-collection wipe on a bad restore.
  - Added `CSVDocument` and `BackupDocument`, two `FileDocument`-conforming wrapper structs backing the
    `.fileExporter` calls. Hit and fixed a real compile error here (not the usual stale-SourceKit noise):
    this SDK's `FileWrapper` initializer is `regularFileWithContents:`, not `regularFileContents:`.
- `SettingsView.swift` — added `import UniformTypeIdentifiers`; state for the `CSVDocument`/`BackupDocument`
  documents and import/export presentation flags; a private `PassphrasePurpose` enum (`.creatingBackup` /
  `.restoringBackup(Data)`) driving a single shared `SecureField`-based `.alert` reused for both create and
  restore; a status-message `.alert` for success/error feedback. Added `.fileExporter`/`.fileImporter`
  modifiers for both CSV and the encrypted backup, following the same security-scoped-resource-access
  pattern already used in `AddWatchView`/`AddProvenanceDocView`. A successful restore also calls
  `NotificationManager.rescheduleAll(for:)` so restored watches get Phase 5's maintenance reminders
  immediately rather than waiting for next launch. Removed the Data section's `.disabled(true)` and updated
  its footer text.
- Updated `horology_vault_monetization_plan.md`: Section 6's Phase 6 header marked "✅ Done (2026-07-14)"
  with a description matching the work above; Section 5.1's "Built so far" gained a bullet for the feature;
  Section 5.2's gap list shrank from 5 items to 4 (renumbered, intro line updated to "Phases 1–6 ...
  complete"); Section 9 (Open Decisions) gained a bullet about whether "Restore from Backup" should
  eventually offer a true replace-all mode instead of staying additive-only.
- Updated `CLAUDE.md`: "Project state" now mentions `DataBackupManager.swift` and the Phases 1–6 done /
  7–9 remaining split; the Architecture section's view-hierarchy bullet now describes `SettingsView`'s
  working Data section instead of "stubbed/disabled"; the Persistence bullet gained a paragraph describing
  `DataBackupManager`'s CSV and encrypted-backup responsibilities and the additive-restore design choice.
- Verified every change with `xcodebuild -project "Horology Vault.xcodeproj" -scheme "Horology Vault"
  -destination 'platform=macOS' build` after editing. One real compile error was hit and fixed (the
  `FileWrapper` initializer label above) plus a minor actor-isolation warning (fixed by wrapping a bare
  function reference passed to `.map` in an explicit closure) — final build succeeded (BUILD SUCCEEDED). As
  in every prior session, SourceKit/editor diagnostics repeatedly showed stale "Cannot find type X in scope"
  errors for types that demonstrably compiled fine — known editor-index lag, distinct from the one genuine
  compile error actually fixed this session.

### Pending / next steps

- Remaining phases from the monetization plan's Section 6, in order: Phase 7 (authorized service center
  directory — bundled static dataset, not started), Phase 8 (`Entitlements` model + `PurchaseManager` +
  StoreKit 2 — the app currently has zero purchase gating), Phase 9 (tests — no automated coverage exists
  for any model/view added since the default Xcode scaffold).
- Open design question flagged in the plan's Section 9: whether "Restore from Backup" should stay additive
  (current behavior) or gain a true replace-all mode — a power user restoring onto a fresh install may
  expect exact replacement rather than a merge.
- The encrypted backup's key derivation is intentionally lightweight (SHA256 of the passphrase, no PBKDF2/
  salt) — fine for deterring casual access to a local file, but revisit if backups are ever synced/shared
  in a way that raises the threat model.

## 2026-07-14

### Accomplished this session

- Implemented Phase 5 of the monetization plan's Section 6 ordered plan: **Maintenance reminders (local
  notifications)**.
- Added `Horology Vault/NotificationManager.swift` — a static-only enum wrapping `UNUserNotificationCenter`:
  `requestAuthorizationIfNeeded()` (only prompts if authorization status is still `.notDetermined`),
  `scheduleServiceDueReminder(for:)` (cancels any existing pending request for the watch, then schedules a
  `UNCalendarNotificationRequest` if `serviceDueDate` is still in the future), `cancelServiceDueReminder(for:)`,
  and `rescheduleAll(for:)`. Notification identifiers are derived from `watch.persistentModelID` (stable from
  insert onward in SwiftData) rather than a new stored field, so no schema/migration change was needed.
- Refactored `Watch.swift`: extracted a new `serviceDueDate: Date?` computed property (`lastServiceDate ??
  acquisitionDate` + 3 years) and rewrote `isServiceDue` to just compare against it — `MaintenanceView` and
  `NotificationManager` now share one source of truth for the due date instead of duplicating the 3-year math.
- `ContentView.swift` — added `@Query private var watches: [Watch]` and a `.task` on the root
  `NavigationSplitView` that requests authorization then reschedules every watch's reminder once at launch
  (covers data changed outside the app's own CRUD flows, e.g. a future restored backup).
- `AddWatchView.swift`'s `save()` — captures the saved/edited watch into a `targetWatch` local and schedules
  its reminder before dismissing, covering both create and edit.
- `WatchDetailView.swift` — `AddServiceRecordView.save()` reschedules the reminder after inserting a new
  `ServiceRecord` (logging a service resets the 3-year clock); the toolbar Delete `confirmationDialog`'s
  destructive button now cancels the reminder before deleting the watch.
- `VaultGridView.swift` — the context-menu Delete `confirmationDialog`'s destructive button likewise cancels
  the reminder before deleting.
- Updated `horology_vault_monetization_plan.md`: Section 6's Phase 5 header marked "✅ Done (2026-07-14)"
  with a description of what was actually built; Section 5.1's "Built so far" gained a bullet for the
  notification feature; Section 5.2's gap list shrank from 6 items to 5 (maintenance-reminders gap removed,
  list renumbered, intro line updated to "Phases 1–5 ... complete").
- Updated `CLAUDE.md`: "Project state" now mentions `NotificationManager.swift` and the Phases 1–5 done /
  6–9 remaining split; the Architecture section's view-hierarchy bullet and Persistence bullet both gained
  descriptions of the shared `serviceDueDate` property and where scheduling/cancellation is called from.
- Verified every change with `xcodebuild -project "Horology Vault.xcodeproj" -scheme "Horology Vault"
  -destination 'platform=macOS' build` after editing — both intermediate and final builds succeeded (BUILD
  SUCCEEDED). As in prior sessions, SourceKit/editor diagnostics repeatedly showed stale "Cannot find type X
  in scope" errors for types that demonstrably compiled fine — known editor-index lag, not a real error.

### Pending / next steps

- Remaining phases from the monetization plan's Section 6, in order: Phase 6 (data import/export +
  encrypted backup — the Data section's buttons in `SettingsView` are still no-ops), Phase 7 (authorized
  service center directory — bundled static dataset, not started), Phase 8 (`Entitlements` model +
  `PurchaseManager` + StoreKit 2 — the app currently has zero purchase gating), Phase 9 (tests — no
  automated coverage exists for any model/view added since the default Xcode scaffold).
- Reminder scheduling has no user-facing controls yet (no way to disable reminders, no lead-time
  customization before the due date) — not called for by the plan yet, but worth flagging if requested.
- Notifications currently fire on the due date itself, not some number of days in advance — matches the
  plan's Phase 5 description as written; revisit if a "days before" lead time proves more useful in practice.

## 2026-07-13 — Session 2

### Accomplished this session

- Planning-only session, no Swift code touched: reviewed `horology_vault_market_research.md` (already in
  the repo from the prior session) and folded its recommendations into
  `horology_vault_monetization_plan.md`.
- Updated the top revision note to mention the new Section 10 and explain why Sections 1, 4, and 9 changed.
- Added a "Competitive position" column to both Section 1 feature tables: Fit Calculator and Strap
  Recommendations w/ affiliate links tagged as genuine differentiators (no competitor found offering
  either); Vault, Service History, WearLog, Wishlist, Provenance, Strap Inventory, Maintenance reminders,
  and import/export tagged as table stakes; Cloud Sync flagged as a risk rather than a differentiator since
  WatchGrid and Watch Collector already give iCloud/CloudKit sync away free; service center directory
  tagged as a minor niche (only Bezelio is adjacent).
- Reordered Section 4's V2 rollout plan: the strap pricing proxy / Strap Recommendations backend service
  now ships first among the three V2 backend services (ahead of the Market Value feed and the Sync/backup
  store), with a suggestion to validate it as a cheap hand-curated affiliate-link MVP before investing in
  full retailer scraping/API integration. Reordered the subscription-gated screen rollout to: Strap
  Recommendations, Market Value, Wishlist price alerts, Cloud Sync, Community, Insurance PDF export.
- Added two new bullets to Section 9 (Open Decisions): whether Cloud Sync can justify a subscription at all
  given free competitor offerings, and whether to MVP the strap pricing proxy before the full build.
- Added a brand-new Section 10, "Competitive Positioning (Market Research, 2026-07-13)", summarizing the
  market research doc's bottom line (crowded but winnable category; Fit Calculator and Strap
  Recommendations are the only two genuinely unclaimed features; the one-time-purchase pricing pattern
  observed across competitors validates this plan's hybrid model; risk of shipping "just another tracker")
  and explicitly listing the three resulting plan changes above.
- Confirmed no changes were needed to Section 6 (the ordered V1 implementation phases) — this update is
  scoped to V2/subscription positioning and doesn't affect the local-only V1 work still in progress (Phases
  5–9 remain not started). Also confirmed CLAUDE.md's existing references to the plan's Section 5/6 are
  still accurate as-is, since Section 10 was appended after Section 9 rather than inserted, so no
  renumbering occurred and no CLAUDE.md edit was needed.

### Pending / next steps

- Everything from the prior 2026-07-13 session's "Pending / next steps" still applies unchanged: Phases
  5–9 of Section 6 (maintenance reminders, data import/export, service center directory,
  Entitlements/StoreKit 2, tests) are not started.
- New open decisions from this session's Section 9 additions: whether Cloud Sync can carry a subscription
  on its own given free competitor sync, and whether to build a cheap hand-curated MVP of Strap
  Recommendations before investing in the full retailer scraping/API-driven pricing proxy.

## 2026-07-13

### Accomplished this session

- Reviewed `horology_vault_monetization_plan.md` against the codebase and added two new sections:
  "5. Implementation Status" (built-so-far vs. gap list) and "6. Next Implementation Steps" (an ordered
  9-phase plan). Renumbered the old Sections 5–7 (SwiftUI View Hierarchy, StoreKit 2 Purchase Flow, Open
  Decisions) to 7–9 to make room.
- Executed Phase 1 of that plan (core CRUD gaps):
  - Added `AddServiceRecordView` (Log Service: date performed, service type, accuracy delta sec/day) and
    `AddStrapView` (Add Strap: name, material, width, length, notes — attaches immediately on save), both
    as private structs inside `WatchDetailView.swift`, wired to new buttons in the Service History and
    Straps sections.
  - Added Delete Watch: context-menu delete on `VaultGridView`'s grid cards, and a destructive toolbar
    button on `WatchDetailView`. Both use `confirmationDialog`.
- Added `Strap.name`, `Strap.lengthMM`, `Strap.notes` fields plus a `summary` computed property
  (`"name · material · width mm"`) used consistently in pickers/labels. The "Attach Strap" picker now shows
  "— attached to Brand Model" when a strap already belongs to a different watch.
- Fixed two UI bugs:
  - `AddWatchView`'s photo preview used a mismatched `.aspectRatio(1, .fill)` + non-square frame combo that
    caused heavy/uneven cropping; changed to `.fit` so the full image shows uncropped.
  - `WatchCardView`'s grid thumbnail now uses on-device Vision saliency detection
    (`VNGenerateAttentionBasedSaliencyImageRequest`) to find the photo's focal point and center the square
    crop on it instead of the geometric center, with EXIF-orientation-aware pixel size handling
    (`uprightPixelSize`/`imageOrientation` in `WatchCardView.swift`) and an animated re-center once the
    async Vision pass resolves.
- Executed Phase 2 (Wear Log): new `WearLog.swift` model (`dateWorn`, `notes`, cascade-deleted with
  `Watch`), registered in the schema; replaced `WatchDetailView`'s Wear Log placeholder with a "Log Today"
  button and a sorted entry list.
- Executed Phase 3 (Provenance): new `ProvenanceDoc.swift` model (`docType` enum: receipt/warranty/
  appraisal, `.externalStorage` file data, `fileName`, `dateAdded`, cascade-deleted with `Watch`),
  registered in the schema; replaced `WatchDetailView`'s Provenance placeholder with an
  `AddProvenanceDocView` sheet (`.fileImporter` for PDF/image on both platforms, since these are documents
  not photos) and a doc list with swipe-to-delete.
- Executed Phase 4 (Fit Calculator): new `FitDiagramView.swift` (`Canvas`-based top-down diagram comparing
  lug-to-lug vs. wrist width, with a fits/overhangs verdict), new `FitCalculatorView.swift` (standalone
  watch-picker screen embedding the diagram), added "Fit Calculator" as a new 5th sidebar entry in
  `ContentView.Section` (between Vault and Wishlist), and upgraded `WatchDetailView`'s Fit Preview section
  to embed `FitDiagramView` instead of two plain `LabeledContent` rows.
- Not called out in the working notes but present in the diff: `Watch` gained an optional
  `referenceNumber` field (surfaced in `AddWatchView` and `WatchDetailView`'s Overview section);
  `AddWatchView` now doubles as the Edit flow via an optional `watchToEdit: Watch?` init parameter, reached
  from a new "Edit" toolbar button on `WatchDetailView`; `AddWatchView`'s macOS photo picker switched from
  `PhotosPicker` to a native `.fileImporter` (PhotosPicker only reaches the macOS Photos library, not
  arbitrary Finder files); and every `Form`-based sheet in the app now applies `.formStyle(.grouped)` on
  macOS for a consistent centered/card layout (`AddWatchView`, `WatchDetailView`, `SettingsView`,
  `AddWishlistItemView`, plus the three new sheets in `WatchDetailView.swift`).
- Added `horology_vault_market_research.md` — a competitive-landscape review of other watch-collection
  apps (WatchGrid, Klokker, Watch Collector, etc.), concluding the Fit Calculator and strap affiliate
  recommendations are the two features no competitor currently has.
- Revised `CLAUDE.md`'s "Project state" and "Architecture" sections in place to describe the
  now-implemented WearLog/Provenance/Fit Calculator/Edit/Delete flows, the expanded schema, the Strap
  `summary` helper, the macOS `.formStyle(.grouped)` convention, and pointers to both plan docs.
- Every change was verified with `xcodebuild -project "Horology Vault.xcodeproj" -scheme "Horology Vault"
  -destination 'platform=macOS' build` after editing — all builds succeeded. SourceKit/editor diagnostics
  repeatedly showed stale "Cannot find type X in scope" errors for types that demonstrably compiled fine;
  treat that as known editor-index lag, not a real error, before chasing it.

### Pending / next steps

- Remaining phases from the monetization plan's Section 6, in order: Phase 5 (maintenance reminders / local
  notifications via `UNNotificationRequest`, driven by `Watch.isServiceDue`), Phase 6 (data import/export +
  encrypted backup — the Data section's buttons in `SettingsView` are still no-ops), Phase 7 (authorized
  service center directory — bundled static dataset, not started), Phase 8 (`Entitlements` model +
  `PurchaseManager` + StoreKit 2 — the app currently has zero purchase gating), Phase 9 (tests — no
  automated coverage exists for any model/view added since the default Xcode scaffold).
- Wear Log has no rotation stats yet (Section 1's "wear tracking & rotation stats") — flagged in Phase 2 as
  a fast-follow once there's enough logged data to make a stat meaningful.
- Open decision carried over from Phase 1: whether Strap creation should get its own standalone sidebar
  screen (browse/edit straps independent of any one watch) instead of the current inline-from-Workbench
  creation — revisit only if strap reuse across many watches becomes common.
- Xcode MCP connection was still blocked by the Gatekeeper/notary check noted in earlier sessions; the
  `ui-designer` agent's live preview tools remain unavailable until that's revisited.

## 2026-07-11

### Accomplished this session

- Removed the Xcode default template scaffold: deleted `Item.swift` and stripped the generated
  list/`addItem`/`deleteItems` boilerplate out of `ContentView.swift`.
- Added the first pass of the SwiftData model layer per the monetization plan's data model:
  `Watch.swift`, `Strap.swift`, `ServiceRecord.swift`, `UserProfile.swift`.
  - `Watch` has a nullify-on-delete relationship to an attached `Strap` and a cascade-delete
    relationship to its `ServiceRecord`s, an `.externalStorage` photo attribute, and computed
    `lastServiceDate` / `isServiceDue` (3-year service interval) properties.
  - `Strap` and `ServiceRecord` are simple models with back-references to `Watch`.
  - `UserProfile` stores wrist measurements (`wristTopWidthCM`, `wristSideDepthCM`) for the fit-preview
    feature.
  - Registered all four new types in the `Schema([...])` in `Horology_Vault_App.swift`.
- Built the initial Vault UI:
  - `VaultGridView` — adaptive `LazyVGrid` of watches with brand/acquisition-date/case-size sorting,
    an empty state via `ContentUnavailableView`, and `NavigationStack` + `navigationDestination` wiring
    to `WatchDetailView`.
  - `WatchCardView` — photo thumbnail (with `UIImage`/`NSImage` bridging for iOS/macOS) and a
    service-due badge.
  - `WatchDetailView` — `Form` with Overview, Straps (attach/detach picker filtered by matching lug
    width), Service History (embeds `AccuracyChartView`), and placeholder Wear Log / Provenance / Fit
    Preview sections.
  - `AccuracyChartView` — `Charts` line mark of accuracy drift (sec/day) over service history, with an
    empty state when no service records exist.
  - `ContentView` now just renders `VaultGridView`.
- Updated `CLAUDE.md` to describe the actual current model/view layer instead of the stale "brand-new
  scaffold, no feature code" description.
- Added a `.claude/` directory with a `close-session` agent and local settings (not previously tracked).

### Pending / next steps

- `WearLog`, `Wishlist`, `ProvenanceDocs`, and `Entitlements` models from the monetization plan are not
  yet implemented; `WatchDetailView`'s Wear Log and Provenance sections are still placeholder text.
- No "Add Watch" / "Add Strap" / "Log Service" creation flows exist yet — the grid can only display
  watches that are seeded some other way (e.g. via previews or manual SwiftData inserts).
- No paywall/StoreKit 2 purchase flow or `Entitlements` gating has been started; V1 feature scope per
  the monetization plan is still to be scaffolded.
- Fit Preview section in `WatchDetailView` only prints lug-to-lug and wrist width side by side — no
  actual fit visualization/algorithm yet.
- No automated tests were added for the new models/views; `Horology Vault"Tests` still only has the
  default Swift Testing scaffold.
- Xcode MCP connection is still blocked by a Gatekeeper/notary check on the CLI's bundle (see
  memory note `xcode_mcp_notary_blocker`), so the `ui-designer` agent's preview tools remain unavailable
  until that's revisited.

## 2026-07-11 — Session 2

### Accomplished this session

- Replaced the single-view `ContentView` with a root `NavigationSplitView`: a sidebar
  (`ContentView.Section` — Vault, Wishlist, Maintenance, Settings) drives which top-level view renders in
  the detail column, with each section owning its own internal `NavigationStack`.
- Added `AddWatchView`, a sheet form (Details, a curated Complications picker, Measurements, Photo via
  `PhotosPicker`) wired to a new "+" toolbar button on `VaultGridView`; save is gated on case diameter,
  lug-to-lug, and lug width all being positive in addition to non-empty brand/model.
- Added the Wishlist feature: a new `WishlistItem` `@Model` (brand, model, targetPrice, notes,
  priceAlertEnabled) registered in the SwiftData schema, plus `WishlistView` (sorted list, empty state, add
  sheet, swipe-to-delete) with a price-alert toggle present but disabled pending V2.
- Added `MaintenanceView`: watches split into "Service Due" / "Up to Date" sections via `Watch.isServiceDue`,
  sorted by last-service/acquisition date, rows pushing into `WatchDetailView`.
- Added `SettingsView`: wrist profile editing (auto-creates a `UserProfile` if none exists yet), plus
  disabled/stubbed Data (CSV import/export, encrypted backup/restore) and Purchase (version badge, restore
  purchase) sections, and an About section.
- Revised `CLAUDE.md`'s Architecture section in place to describe the new sidebar/`NavigationSplitView`
  structure, the expanded view hierarchy (Wishlist/Maintenance/Settings siblings), the
  `AddWatchView` validation rule, and the updated SwiftData schema (`WishlistItem` added).

### Pending / next steps

- `WearLog`, `ProvenanceDocs`, and `Entitlements` models from the monetization plan are still not
  implemented.
- `SettingsView`'s Data section (CSV import/export, encrypted backup/restore) and Purchase section
  (StoreKit 2, restore purchase) are UI-only stubs with no wired logic yet.
- Wishlist price-alert toggle is a disabled placeholder pending V2 backend price-polling.
- Fit Preview in `WatchDetailView` still just prints lug-to-lug and wrist width side by side — no real fit
  visualization/algorithm yet.
- No automated tests were added for any of the new views/models (`AddWatchView`, `WishlistItem`,
  `MaintenanceView`, `SettingsView`).
- Xcode MCP connection is still blocked by the Gatekeeper/notary check noted above; revisit before relying
  on the `ui-designer` agent's preview tools.
