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
  `ContentView.swift` is now a thin wrapper that just renders `VaultGridView`, which owns its own
  `NavigationStack` and pushes `WatchDetailView` via `.navigationDestination(for: Watch.self)`. Platform
  differences are handled inline with `#if os(macOS)` / `#if os(iOS)` where needed (e.g. the
  `UIImage`/`NSImage` bridging in `WatchCardView.swift`, `.navigationBarTitleDisplayMode` in
  `WatchDetailView.swift`) rather than separate platform targets — keep new platform-specific UI on this
  same pattern.
- **View hierarchy so far:** `VaultGridView` (grid of watches with brand/date/case-size sorting, empty
  state via `ContentUnavailableView`) → `WatchCardView` (photo thumbnail + service-due badge) →
  `WatchDetailView` (Form with Overview, Straps, Service History incl. `AccuracyChartView` line chart via
  `Charts`, and placeholder Wear Log / Provenance / Fit Preview sections).
- **Persistence:** SwiftData (`ModelContainer` / `@Query` / `@Model`), configured once in
  `Horology_Vault_App.swift` and injected via `.modelContainer(...)`. Current schema is
  `[Watch.self, Strap.self, ServiceRecord.self, UserProfile.self]`. `Watch` cascades-deletes its
  `ServiceRecord`s and nullifies its `Strap` relationship on delete; `Watch.isServiceDue` flags watches
  more than 3 years past their last (or acquisition) date. The monetization plan calls for an
  `Entitlements` table driving all feature gating (`is_lifetime_unlocked`, `subscription_status`) that the
  UI reads but never writes directly — writes only happen from the StoreKit transaction listener; this
  table does not exist yet. When adding new `@Model` types, register them in the `Schema([...])` array in
  `Horology_Vault_App.swift`.
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
