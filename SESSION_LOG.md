# Session Log

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
