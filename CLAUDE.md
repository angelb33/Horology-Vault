# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

The Xcode default template has been replaced with the start of the real app. The SwiftData model layer
(`Watch.swift`, `Strap.swift`, `ServiceRecord.swift`, `UserProfile.swift`) and a first pass at the Vault UI
(`VaultGridView.swift`, `WatchCardView.swift`, `WatchDetailView.swift`, `AccuracyChartView.swift`) now exist;
`Item.swift` (the scaffold model) has been deleted and `ContentView.swift` now just hosts `VaultGridView`.
`WearLog`, `Wishlist`, `ProvenanceDocs`, and `Entitlements` from the plan are not yet modeled — the detail
view has placeholder sections for wear log and provenance. The intended product and technical design live
in `horology_vault_monetization_plan.md` at the repo root — read it before implementing features, since it
defines the full planned data model (`Watches`, `Straps`, `ServiceHistory`, `WearLog`, `Wishlist`,
`ProvenanceDocs`, `Entitlements`), the entitlement/paywall architecture, the V1 (one-time purchase, fully
local/offline) vs. V2 (subscription, needs backend services) feature split, the planned SwiftUI view
hierarchy, and the StoreKit 2 purchase flow. Treat that doc as the source of truth for "why" a feature is
scoped the way it is; implement against it rather than re-deriving architecture from scratch.

## ⚠️ Naming gotcha: embedded quote character

The project was created with a literal trailing double-quote (`"`) in its name. This is **not a typo to
fix** — it is baked into the folder names, the Xcode target/scheme names, and the derived bundle
identifiers:

- Folder: `Horology Vault"/` (app sources), `Horology Vault"Tests/`, `Horology Vault"UITests/`
- Xcode project: `Horology Vault".xcodeproj`
- Targets/scheme (all literally end in `"`): `Horology Vault"`, `Horology Vault"Tests`, `Horology Vault"UITests`
- Bundle IDs: `com.angelburgos.Horology-Vault-`, `com.angelburgos.Horology-Vault-Tests`, `com.angelburgos.Horology-Vault-UITests`

Every shell command below needs the `"` escaped (`\"`) when double-quoting the path, or the whole name
single-quoted. Do not "fix" the stray quote in file headers, folder names, or the `.xcodeproj` unless the
user explicitly asks for a project rename (renaming an Xcode project touches the `.xcodeproj`, all target
names, scheme files, and bundle identifiers, and is not a simple find-and-replace).

## Common commands

Run from the repo root (`Horology Vault App/`). All commands must run on macOS with Xcode installed.

**Build (macOS):**
```bash
xcodebuild -project "Horology Vault\".xcodeproj" -scheme "Horology Vault\"" -destination 'platform=macOS' build
```

**Build (iOS Simulator):**
```bash
xcodebuild -project "Horology Vault\".xcodeproj" -scheme "Horology Vault\"" -destination 'platform=iOS Simulator,name=iPhone 16' build
```

**Run all tests (unit + UI):**
```bash
xcodebuild -project "Horology Vault\".xcodeproj" -scheme "Horology Vault\"" -destination 'platform=macOS' test
```

**Run a single test** (Swift Testing syntax, e.g. the `example()` test in `Horology_Vault_Tests.swift`):
```bash
xcodebuild -project "Horology Vault\".xcodeproj" -scheme "Horology Vault\"" -destination 'platform=macOS' \
  test -only-testing:"Horology Vault\"Tests/Horology_Vault_Tests/example"
```

**List targets/schemes** (useful for confirming exact quoting when a command fails):
```bash
xcodebuild -list -project "Horology Vault\".xcodeproj"
```

Alternatively, open `Horology Vault".xcodeproj` in Xcode and use Cmd+R / Cmd+U — this sidesteps all the
shell-quoting issues above.

## Architecture

- **UI framework:** SwiftUI, single multiplatform target shared across iOS, macOS, and visionOS
  (`SUPPORTED_PLATFORMS = iphoneos iphonesimulator macosx xros xrsimulator`, `TARGETED_DEVICE_FAMILY = 1,2,7`).
  `ContentView.swift` hosts the app's root `NavigationSplitView`: a sidebar (`ContentView.Section` — Vault,
  Wishlist, Maintenance, Settings) drives which top-level view renders in the detail column. Each top-level
  view (`VaultGridView`, `WishlistView`, `MaintenanceView`, `SettingsView`) owns its own internal
  `NavigationStack` for push navigation within that section (e.g. `VaultGridView` and `MaintenanceView` both
  push `WatchDetailView` via `.navigationDestination(for: Watch.self)`) — this is the standard nested-stack
  pattern for `NavigationSplitView` detail columns, not a leftover to clean up. Platform differences are
  handled inline with `#if os(macOS)` / `#if os(iOS)` where needed (e.g. the `UIImage`/`NSImage` bridging in
  `WatchCardView.swift`, `.navigationBarTitleDisplayMode` in `WatchDetailView.swift`,
  `.navigationSplitViewColumnWidth` on the sidebar) rather than separate platform targets — keep new
  platform-specific UI on this same pattern. The V2 sidebar sections (Strap Shop, Market Value, Community)
  from the plan are intentionally not added yet — they stay hidden until the subscription ships.
- **View hierarchy so far:** sidebar → `VaultGridView` (grid of watches with brand/date/case-size sorting,
  empty state via `ContentUnavailableView`, `+` toolbar button sheets `AddWatchView`) → `WatchCardView`
  (photo thumbnail + service-due badge) → `WatchDetailView` (Form with Overview, Straps, Service History
  incl. `AccuracyChartView` line chart via `Charts`, and placeholder Wear Log / Provenance / Fit Preview
  sections). Sibling sections: `WishlistView` (list of `WishlistItem`, price-alert toggle present but
  disabled pending V2), `MaintenanceView` (watches split into Service Due / Up to Date via
  `Watch.isServiceDue`, rows push into `WatchDetailView`), `SettingsView` (wrist profile editing, stubbed/
  disabled Data and Purchase sections pending CSV/backup and StoreKit work).
- **Persistence:** SwiftData (`ModelContainer` / `@Query` / `@Model`), configured once in
  `Horology_Vault_App.swift` and injected via `.modelContainer(...)`. Current schema is
  `[Watch.self, Strap.self, ServiceRecord.self, UserProfile.self, WishlistItem.self]`. `Watch`
  cascades-deletes its `ServiceRecord`s and nullifies its `Strap` relationship on delete; `Watch.isServiceDue`
  flags watches more than 3 years past their last (or acquisition) date. `AddWatchView`'s save action
  requires case diameter, lug-to-lug, and lug width to all be positive (not just brand/model non-empty) —
  those specs are read-only everywhere else in the app once a watch is created, so bad data saved there
  can't currently be corrected. The monetization plan calls for an `Entitlements` table driving all feature
  gating (`is_lifetime_unlocked`, `subscription_status`) that the UI reads but never writes directly — writes
  only happen from the StoreKit transaction listener; this table does not exist yet. When adding new
  `@Model` types, register them in the `Schema([...])` array in `Horology_Vault_App.swift`.
- **Test frameworks:** unit tests (`Horology Vault"Tests/`) use the new **Swift Testing** framework
  (`import Testing`, `@Test`, `#expect`), not XCTest. UI tests (`Horology Vault"UITests/`) use XCTest/XCUITest.
  Match whichever framework the target file already uses.
- **Deployment target:** iOS/macOS 26.5 (`IPHONEOS_DEPLOYMENT_TARGET` / `MACOSX_DEPLOYMENT_TARGET = 26.5`),
  Swift 5.0 language mode.
- **Monetization/entitlement design:** see `horology_vault_monetization_plan.md` for the full picture. Key
  point for implementation ordering: V1 is 100% local/offline (no backend), gated only by
  `is_lifetime_unlocked`; subscription-only features (market data, cloud sync, community) and their backend
  services are explicitly out of scope until V1 has traction — don't build backend/network code for those
  screens prematurely.
