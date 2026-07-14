# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

The Xcode default template has been replaced with the real app, and V1's local-only feature set (Section 1
of the monetization plan) is now mostly built out. The SwiftData model layer (`Watch.swift`, `Strap.swift`,
`ServiceRecord.swift`, `UserProfile.swift`, `WishlistItem.swift`, `WearLog.swift`, `ProvenanceDoc.swift`) and
the Vault UI (`VaultGridView.swift`, `WatchCardView.swift`, `WatchDetailView.swift`, `AccuracyChartView.swift`,
`FitDiagramView.swift`, `FitCalculatorView.swift`) now exist; `Item.swift` (the scaffold model) has been
deleted and `ContentView.swift` hosts the sidebar-driven `NavigationSplitView`. `WatchDetailView` ("the
Workbench") now has a working create/edit flow for every section it shows — Edit Watch, Delete Watch, Log
Service, Add/Attach Strap, Log Wear, Add Provenance Document — so the app is no longer a read-only display
once a watch exists. `NotificationManager.swift` schedules a local "service due" reminder per watch (see
Architecture below), so Maintenance is no longer a read-only list either. Only `Entitlements` from the plan
is still unmodeled: nothing in the app currently reads or writes any unlock state, so the app is fully open
with zero purchase gating. The intended product and technical design live in
`horology_vault_monetization_plan.md` at the repo root — read it before implementing features, since it
defines the full planned data model (`Watches`, `Straps`, `ServiceHistory`, `WearLog`, `Wishlist`,
`ProvenanceDocs`, `Entitlements`), the entitlement/paywall architecture, the V1 (one-time purchase, fully
local/offline) vs. V2 (subscription, needs backend services) feature split, the planned SwiftUI view
hierarchy, and the StoreKit 2 purchase flow. Section 5 of that doc tracks exactly what's built vs.
outstanding as of the last review, and Section 6 is the ordered implementation plan — Phases 1–5 (core CRUD
gaps, Wear Log, Provenance, Fit Calculator, Maintenance reminders) are done; Phases 6–9 (import/export/
backup, service center directory, Entitlements/StoreKit 2, and tests) are not started. Treat that doc as the
source of truth for "why" a feature is scoped the way it is; implement against it rather than re-deriving
architecture from scratch. `horology_vault_market_research.md` at the repo root has a competitive-landscape
review of other watch-collection apps (WatchGrid, Klokker, Watch Collector, etc.) — read it for which
planned features are genuine differentiators (Fit Calculator, strap affiliate recommendations) vs. table
stakes everyone already has (wear tracking, service history, wishlist); Section 10 of the monetization plan
summarizes that review and the roadmap changes it drove (V2 leads with Strap Recommendations, Cloud Sync
flagged as a weak subscription pillar since competitors give it away free).

## Common commands

Run from the repo root (`Horology Vault App/Horology Vault/`). All commands must run on macOS with Xcode installed.

**Build (macOS):**
```bash
xcodebuild -project "Horology Vault.xcodeproj" -scheme "Horology Vault" -destination 'platform=macOS' build
```

**Build (iOS Simulator):**
```bash
xcodebuild -project "Horology Vault.xcodeproj" -scheme "Horology Vault" -destination 'platform=iOS Simulator,name=iPhone 16' build
```

**Run all tests (unit + UI):**
```bash
xcodebuild -project "Horology Vault.xcodeproj" -scheme "Horology Vault" -destination 'platform=macOS' test
```

**Run a single test** (Swift Testing syntax, e.g. the `example()` test in `Horology_Vault_Tests.swift`):
```bash
xcodebuild -project "Horology Vault.xcodeproj" -scheme "Horology Vault" -destination 'platform=macOS' \
  test -only-testing:"Horology VaultTests/Horology_Vault_Tests/example"
```

**List targets/schemes:**
```bash
xcodebuild -list -project "Horology Vault.xcodeproj"
```

Alternatively, open `Horology Vault.xcodeproj` in Xcode and use Cmd+R / Cmd+U.

Note: the project previously had a literal trailing double-quote baked into its name (folders, target/scheme
names, bundle IDs) — this has been removed via Xcode's rename tooling plus manual bundle-ID/header cleanup.
Bundle IDs are now `com.angelburgos.HorologyVault`, `com.angelburgos.HorologyVaultTests`,
`com.angelburgos.HorologyVaultUITests`. The quote had also broken Xcode's Canvas Preview (`#sourceLocation`
directives choked on the embedded `"` in the file path) — Canvas Previews should now work normally.

## Architecture

- **UI framework:** SwiftUI, single multiplatform target shared across iOS, macOS, and visionOS
  (`SUPPORTED_PLATFORMS = iphoneos iphonesimulator macosx xros xrsimulator`, `TARGETED_DEVICE_FAMILY = 1,2,7`).
  `ContentView.swift` hosts the app's root `NavigationSplitView`: a sidebar (`ContentView.Section` — Vault,
  Fit Calculator, Wishlist, Maintenance, Settings) drives which top-level view renders in the detail column.
  Each top-level view (`VaultGridView`, `FitCalculatorView`, `WishlistView`, `MaintenanceView`,
  `SettingsView`) owns its own internal `NavigationStack` for push navigation within that section (e.g.
  `VaultGridView` and `MaintenanceView` both push `WatchDetailView` via `.navigationDestination(for:
  Watch.self)`) — this is the standard nested-stack pattern for `NavigationSplitView` detail columns, not a
  leftover to clean up. Platform differences are handled inline with `#if os(macOS)` / `#if os(iOS)` where
  needed (e.g. the `UIImage`/`NSImage` bridging in `WatchCardView.swift`, `.navigationBarTitleDisplayMode` in
  `WatchDetailView.swift`, `.navigationSplitViewColumnWidth` on the sidebar) rather than separate platform
  targets — keep new platform-specific UI on this same pattern. Every `Form`-based sheet uses
  `.formStyle(.grouped)` under `#if os(macOS)` (AddWatchView, WatchDetailView, SettingsView,
  AddWishlistItemView, and the three sheets nested in WatchDetailView.swift) since the default macOS Form
  style left-aligns sections in a narrow column instead of the centered, card-style layout `.grouped` gives —
  follow this pattern for any new sheet. The V2 sidebar sections (Strap Shop, Market Value, Community) from
  the plan are intentionally not added yet — they stay hidden until the subscription ships.
- **View hierarchy so far:** sidebar → `VaultGridView` (grid of watches with brand/date/case-size sorting,
  empty state via `ContentUnavailableView`, `+` toolbar button sheets `AddWatchView`, context-menu Delete
  with a `confirmationDialog`) → `WatchCardView` (photo thumbnail, smart-cropped via Vision saliency
  detection so the square crop centers on the subject rather than the geometric center — see
  `WatchCardView.swift`'s `saliencyFocusPoint`/`SmartCroppedImage` — plus a service-due badge) →
  `WatchDetailView` ("the Workbench": Form with an Edit toolbar button reopening `AddWatchView` pre-filled,
  a destructive Delete toolbar button, and these sections: Overview incl. optional reference number, Straps
  (attach/detach picker + "Add New Strap…" → `AddStrapView` sheet, flags straps already attached elsewhere),
  Service History (`AccuracyChartView` chart + "Log Service…" → `AddServiceRecordView` sheet), Wear Log
  ("Log Today" button + sorted `WearLog` entries), Provenance ("Add Document…" → `AddProvenanceDocView`
  sheet using `.fileImporter` for PDF/image + swipe-to-delete list), and Fit Preview (embeds
  `FitDiagramView`)). `AddStrapView`/`AddServiceRecordView`/`AddProvenanceDocView` are private structs
  defined inside `WatchDetailView.swift`, not separate files. Sibling sections: `FitCalculatorView`
  (standalone watch picker embedding `FitDiagramView`, a `Canvas`-based top-down lug-to-lug-vs-wrist diagram
  with a fits/overhangs verdict), `WishlistView` (list of `WishlistItem`, price-alert toggle present but
  disabled pending V2), `MaintenanceView` (watches split into Service Due / Up to Date via
  `Watch.isServiceDue`, rows push into `WatchDetailView`), `SettingsView` (wrist profile editing, stubbed/
  disabled Data and Purchase sections pending CSV/backup and StoreKit work). `NotificationManager.swift` (a
  static-only enum, not a view) schedules/cancels the local "service due" reminder per watch — see
  Persistence below for the due-date math it shares with `Watch.isServiceDue`.
- **Persistence:** SwiftData (`ModelContainer` / `@Query` / `@Model`), configured once in
  `Horology_Vault_App.swift` and injected via `.modelContainer(...)`. Current schema is
  `[Watch.self, Strap.self, ServiceRecord.self, UserProfile.self, WishlistItem.self, WearLog.self,
  ProvenanceDoc.self]`. `Watch` cascade-deletes its `ServiceRecord`s, `WearLog`s, and `ProvenanceDoc`s, and
  nullifies its `Strap` relationship on delete; `Watch.isServiceDue` flags watches more than 3 years past
  their last (or acquisition) date, now derived from a shared `Watch.serviceDueDate` computed property so
  `MaintenanceView` and `NotificationManager`'s reminder scheduling can never disagree on the due date.
  `NotificationManager.scheduleServiceDueReminder(for:)`/`cancelServiceDueReminder(for:)` are called from
  `AddWatchView.save()` (create + edit), `AddServiceRecordView.save()` (logging a service resets the
  3-year clock), and both delete paths (`WatchDetailView`'s toolbar Delete, `VaultGridView`'s context-menu
  Delete); `ContentView` requests notification authorization and reschedules every watch once at launch.
  Reminder identifiers are derived from `watch.persistentModelID` rather than a new stored field — no
  schema change was needed for this feature. `Watch` also has an optional `referenceNumber`. `Strap` has optional
  `name`, `lengthMM`, and `notes` fields plus a `summary` computed property (`"name · material · width mm"`,
  name omitted if unset) used consistently in pickers/labels — use `strap.summary` rather than re-deriving
  that string. `ProvenanceDoc.fileData` is `@Attribute(.externalStorage)`, same pattern as
  `Watch.photoData`, so large PDFs/images don't bloat the SwiftData store file. `AddWatchView`'s save action
  requires case diameter, lug-to-lug, and lug width to all be positive (not just brand/model non-empty), and
  now doubles as the edit flow via an optional `watchToEdit: Watch?` init param — `WatchDetailView`'s Edit
  button reopens it pre-filled. `AddWatchView`'s photo picker is `PhotosPicker` on iOS but a native
  `.fileImporter` on macOS (PhotosPicker there only browses the macOS Photos library, not arbitrary Finder
  files); `AddProvenanceDocView` uses `.fileImporter` with `[.pdf, .image]` on both platforms since documents
  aren't photos. The monetization plan calls for an `Entitlements` table driving all feature gating
  (`is_lifetime_unlocked`, `subscription_status`) that the UI reads but never writes directly — writes only
  happen from the StoreKit transaction listener; this table does not exist yet (Phase 8 of the plan's Section
  6). When adding new `@Model` types, register them in the `Schema([...])` array in `Horology_Vault_App.swift`.
- **Test frameworks:** unit tests (`Horology VaultTests/`) use the new **Swift Testing** framework
  (`import Testing`, `@Test`, `#expect`), not XCTest. UI tests (`Horology VaultUITests/`) use XCTest/XCUITest.
  Match whichever framework the target file already uses.
- **Deployment target:** iOS/macOS 26.5 (`IPHONEOS_DEPLOYMENT_TARGET` / `MACOSX_DEPLOYMENT_TARGET = 26.5`),
  Swift 5.0 language mode.
- **Monetization/entitlement design:** see `horology_vault_monetization_plan.md` for the full picture. Key
  point for implementation ordering: V1 is 100% local/offline (no backend), gated only by
  `is_lifetime_unlocked`; subscription-only features (market data, cloud sync, community) and their backend
  services are explicitly out of scope until V1 has traction — don't build backend/network code for those
  screens prematurely.
