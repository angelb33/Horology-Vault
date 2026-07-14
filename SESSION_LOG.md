# Session Log

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
