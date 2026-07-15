# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

The Xcode default template has been replaced with the real app, and V1's local-only feature set (Section 1
of the monetization plan) is now fully built out — Phases 1–12 of Section 6's ordered plan are all done. The
SwiftData model layer (`Watch.swift`, `Strap.swift`,
`ServiceRecord.swift`, `UserProfile.swift`, `WishlistItem.swift`, `WearLog.swift`, `ProvenanceDoc.swift`) and
the Vault UI (`VaultGridView.swift`, `WatchCardView.swift`, `WatchDetailView.swift`, `AccuracyChartView.swift`,
`FitDiagramView.swift`, `FitCalculatorView.swift`) now exist; `Item.swift` (the scaffold model) has been
deleted and `ContentView.swift` hosts the sidebar-driven `NavigationSplitView`. `WatchDetailView` ("the
Workbench") now has a working create/edit flow for every section it shows — Edit Watch, Delete Watch, Log
Service, Add/Attach Strap, Log Wear, Add Provenance Document — so the app is no longer a read-only display
once a watch exists. `NotificationManager.swift` schedules a local "service due" reminder per watch (see
Architecture below), so Maintenance is no longer a read-only list either, `DataBackupManager.swift` wires
up `SettingsView`'s CSV export/import and encrypted backup/restore buttons, and `ServiceCentersView.swift`
(backed by `OfficialServiceDirectory.swift`'s bundled manufacturer contacts and the new
`CustomServiceCenter` model for user-added ones) adds a searchable service-center directory as a 6th
sidebar entry. `Entitlements.swift` + `PurchaseManager.swift` (StoreKit 2, one non-consumable lifetime
unlock) gate the Insights dashboard (not new-watch creation — see Architecture below for the 2026-07-14
gating revision); a fresh install seeds one demo watch and opens fully able to add more, with Insights
showing an "Unlock Full Version" paywall instead of a disabled button. One manual (non-code) step remains
before shipping: registering the product in App Store Connect. (Local purchase testing is otherwise fully
set up: a shared scheme at `Horology Vault.xcodeproj/xcshareddata/xcschemes/Horology Vault.xcscheme` now
points StoreKit Configuration at `Configuration.storekit`, so a fresh checkout gets working local purchase
testing without any manual Edit Scheme step — this was a per-machine, uncommitted setting until 2026-07-14.
Ask to Buy is off in that config, so `purchase()` completes immediately rather than going through the
simulated-parental-approval `.pending` path.) The intended product and technical
design live in `horology_vault_monetization_plan.md` at the repo root — read it before implementing
features, since it defines the full planned data model (`Watches`, `Straps`, `ServiceHistory`, `WearLog`,
`Wishlist`, `ProvenanceDocs`, `Entitlements`), the entitlement/paywall architecture, the V1 (one-time
purchase, fully local/offline) vs. V2 (subscription, needs backend services) feature split, the planned
SwiftUI view hierarchy, and the StoreKit 2 purchase flow. Section 5 of that doc tracks exactly what's built
vs. outstanding as of the last review, and Section 6 is the ordered implementation plan — Phases 1–9 (core
CRUD gaps, Wear Log, Provenance, Fit Calculator, Maintenance reminders, Data import/export & backup, Service
center directory, Entitlements/StoreKit 2, tests) are all done. Two more V1-scope phases were added and
shipped 2026-07-14: **Phase 10** (Appearance — `ColorSchemePreference`/`AccentColorOption` enums in
`SettingsView.swift`, `@AppStorage`-backed, applied via `.tint()`/`.preferredColorScheme()` on
`ContentView`'s root, no schema change) and **Phase 11** (a new "Insights" sidebar entry →
`DashboardView.swift`, wrapping `WearFrequencyChartView`, `ServiceStatusChartView`,
`WearServiceCorrelationChartView`, and `CollectionGrowthChartView` — all Swift Charts, needing only one new
computed property, `Watch.wearCountSinceLastService`, covered by 4 new tests in `WatchModelTests.swift`).
Both build cleanly, the full test suite passes (37/37), and the UI itself was manually confirmed working by
the user directly in Xcode (the sandbox this work was implemented in has no Screen Recording/Apple Events
permission, so that verification step couldn't happen from inside the session). A twelfth phase was added
and shipped 2026-07-15: **Phase 12** (Scheduled Automatic Encrypted Backup — `KeychainHelper.swift` and
`ScheduledBackupManager.swift`, see Architecture below). As of 2026-07-15 this is gated behind
`is_lifetime_unlocked`, same as Insights (the manual encrypted backup/CSV buttons stay free regardless —
only the automation layer is gated). Build succeeds on both platforms and the full test
suite passes (10 new cases); end-to-end manual verification (folder picked, passphrase set, a `.hvbackup`
file actually appearing unattended) is still outstanding, same sandbox-interaction limitation as Phases
10–11. Nothing else remains against
this plan's V1 scope. A feature outside the monetization plan's original scope, **Learn Hub**, was added
2026-07-15: a free/ungated educational section (`LearnHubContent.swift`, `LearnHubView.swift`) covering
watch anatomy, movements, complications, materials, straps, care, buying, and a glossary — 50 static
articles across 8 categories, each with its own SF Symbol, and complication topics cross-link into the
user's own Vault via a shared `Watch.commonComplications` vocabulary (see Architecture below for the
full design and a hard-won SF Symbol lesson). Treat that doc as the
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
  Fit Calculator, Wishlist, Maintenance, Service Centers, Settings) drives which top-level view renders in
  the detail column. Each top-level view (`VaultGridView`, `FitCalculatorView`, `WishlistView`,
  `MaintenanceView`, `ServiceCentersView`, `SettingsView`) owns its own internal `NavigationStack` for push
  navigation within that section (e.g.
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
  `Watch.isServiceDue`, rows push into `WatchDetailView`), `ServiceCentersView` (`.searchable` List with two
  independently collapsible `DisclosureGroup` sections — "Manufacturer Support" over
  `OfficialServiceDirectory.contacts` merged with any matching `ServiceContactOverride` (tap a row or use
  its context menu to edit; edited rows get an "Edited" badge and a "Reset to Default" action that just
  deletes the override, since the bundled contact is always the fallback), and "My Service Centers" over
  `@Query`-fetched `CustomServiceCenter`s (tap/context-menu to edit via `AddServiceCenterView`'s
  `centerToEdit` param, swipe-to-delete). Both sections auto-expand while `searchText` is non-empty so a
  query never hides its own results behind a collapsed section. "+" toolbar button → `AddServiceCenterView`
  in create mode), `SettingsView` (wrist profile
  editing, a working Data section — CSV export/import + encrypted backup/restore, see `DataBackupManager`
  below — and a working Purchase section wired to `PurchaseManager`/`Entitlements`, see below).
- **Learn Hub** (added 2026-07-15, `.learnHub` case in `ContentView.Section`, `book.closed` icon, placed
  right after Vault in the sidebar): a free/ungated educational section for horology beginners, not gated
  by `Entitlements` since it's onboarding/retention content rather than a paid feature.
  `LearnHubContent.swift` holds `LearnCategory` (8 cases — Watch Anatomy, Movements, Complications,
  Materials & Case, Straps & Bracelets, Care & Maintenance, Buying & Ownership, Glossary) and `LearnTopic`
  (slug/category/title/summary/body/optional `complicationName`/optional `systemImage`) plus
  `LearnHubContent.topics`, 50 hand-written static articles — following the same bundled-static-data
  pattern as `OfficialServiceDirectory.swift` (a plain Swift literal, not a `@Model`), which is this
  project's precedent for read-only reference content that doesn't belong in the SwiftData schema. Every
  topic has its own SF Symbol (`LearnTopic.displaySystemImage`, falling back to the category's icon when a
  topic doesn't set one) rather than reusing one icon per whole category — **lesson learned the hard way:
  `Image(systemName:)` does not validate at compile time, so a typo'd or non-existent symbol name (this
  project shipped `"feather"`, which isn't a real SF Symbol) builds and tests clean but renders blank at
  runtime.** Before trusting a new SF Symbol name, verify it resolves — e.g. a throwaway script calling
  `NSImage(systemSymbolName:accessibilityDescription:)`/`UIImage(systemName:)` for every candidate string
  and checking for `nil` — rather than assuming a green `xcodebuild build` means the icon exists.
  `LearnHubView.swift` is a category-grouped, `.searchable` list (`ContentUnavailableView.search(text:)`
  empty state, matching `VaultGridView`/`DashboardView`/`MaintenanceView`'s existing pattern) pushing into
  a detail view: `.largeTitle` title, a tinted `CategoryChip` capsule, `.lineSpacing(4)` body text capped
  at `.frame(maxWidth: 700)` so paragraphs don't stretch edge-to-edge unreadably on macOS/iPad. Complication
  topics show an `InYourVaultCard` — a tinted, bordered card (star icon, ownership count, `WatchThumbnail`
  44pt photo rows navigating into `WatchDetailView`) — driven by an `@Query` match against the topic's
  `complicationName`. That cross-link depends on `LearnTopic.complicationName` staying spelled identically
  to `Watch`'s complication vocabulary, so `commonComplications` (`"Date"`, `"Day-Date"`, `"Chronograph"`,
  `"GMT"`, `"Moonphase"`, `"Power Reserve"`, `"World Time"`, `"Perpetual Calendar"`, `"Tourbillon"`,
  `"Alarm"`) was extracted out of `AddWatchView.swift` (where it used to live as a private array) into
  `Watch.swift` as `static let commonComplications`, so both features share one source of truth instead of
  two lists that could silently drift. `WatchThumbnail` is a small, self-contained `UIImage`/`NSImage`
  decode local to `LearnHubView.swift` — it deliberately does **not** reuse `WatchCardView`'s Vision-based
  smart-crop pipeline (overkill for a 44pt list thumbnail), and an earlier attempt to reuse
  `WatchCardView`'s private `platformImage(from:)` by making it internal was reverted after it collided
  with an unrelated identically-named private function already in `AddWatchView.swift` (a redeclaration
  error once exposed module-wide) — keep that function `private` in `WatchCardView.swift`. The UI pass
  (icon-per-topic, typography, `InYourVaultCard`) came from the `ui-designer` subagent's reviewed
  brainstorm; its lower-priority ideas — a category-grid landing screen, tappable related-topic links
  between articles (cross-references already exist in the prose but aren't links yet), a Watch Anatomy
  interactive diagram, a movements comparison table, `@AppStorage`-backed read/progress tracking — are not
  built. Like the rest of this app's UI work, the visual result hasn't been manually eyeballed in Xcode's
  Canvas/Simulator from inside a session (no Screen Recording/Apple Events permission in this sandbox); the
  user should do a final visual pass in Xcode.
  `NotificationManager.swift` (a static-only enum, not a view) schedules/cancels the local "service due"
  reminder per watch — see Persistence below for the due-date math it shares with `Watch.isServiceDue`.
  `PurchaseManager.swift` (an `@Observable` class, not a view either) is injected into the environment from
  `ContentView` via `.environment(purchaseManager)`. **Gating was revised 2026-07-14** (see the monetization
  plan's Section 8 "Gating decision for V1" and Phase 8 follow-up writeup): `VaultGridView`'s "Add Watch" is
  no longer gated at all — blocking the core "add your own collection" action turned out to hurt onboarding
  more than it helped conversion — and the `unlockBanner` it used to show was removed. `Entitlements.isLifetimeUnlocked`
  now gates `DashboardView` (the Insights sidebar entry) instead: `@Query`-read, and when locked the whole
  screen is replaced by a `ContentUnavailableView`-based paywall with an "Unlock Full Version" action, rather
  than disabling a button. Fit Calculator stays open in both states — it's the plan's differentiator feature,
  so hiding it would prevent it from ever doing its job of converting a browser into a buyer. **Scheduled
  Backup joined Insights as gated, 2026-07-15** (see below) — manual export/backup remains free regardless.
  `KeychainHelper.swift` (a static-only enum, no view) wraps Keychain Services
  (`SecItemAdd`/`SecItemCopyMatching`/`SecItemUpdate`/`SecItemDelete`) to store/read/delete the scheduled
  backup's passphrase — the only Keychain code in this project. `ScheduledBackupManager.swift` (another
  static-only enum) is the first place this app's scheduling code needs `#if os(...)` branches: iOS
  registers a `BGProcessingTask` (from `Horology_Vault_App.init()`, since `BGTaskScheduler` registration
  must happen before the app finishes launching — everything else in this app sets up from a `View.task`,
  which is too late for this one call), macOS uses `NSBackgroundActivityScheduler` (started from
  `ContentView.task`, since it only needs to run while the app is alive, no LaunchAgent). Its pure
  `isBackupDue(frequency:lastRunDate:now:calendar:)` function is the only part of this feature that's unit
  tested (`ScheduledBackupManagerTests.swift`) — `performBackupIfDue(context:)` is the actual orchestration,
  reading settings from `UserDefaults.standard` directly (a static enum can't hold `@AppStorage`) and
  gating on `Entitlements.isLifetimeUnlocked` fetched from the passed-in `ModelContext` before doing
  anything else. `SettingsView`'s "Scheduled Backup" section is `@ViewBuilder`-branched on the same
  `isUnlocked` pattern `purchaseStatusSection` already uses, showing a compact in-section paywall row
  instead of `DashboardView`'s full-screen treatment, since it's one `Section` in a multi-section `Form`.
- **Persistence:** SwiftData (`ModelContainer` / `@Query` / `@Model`), configured once in
  `Horology_Vault_App.swift` and injected via `.modelContainer(...)`. Current schema is
  `[Watch.self, Strap.self, ServiceRecord.self, UserProfile.self, WishlistItem.self, WearLog.self,
  ProvenanceDoc.self, CustomServiceCenter.self, Entitlements.self, ServiceContactOverride.self]`. `Watch`
  cascade-deletes its `ServiceRecord`s, `WearLog`s, and `ProvenanceDoc`s, and
  nullifies its `Strap` relationship on delete; `Watch.isServiceDue` flags watches more than 3 years past
  their last (or acquisition) date, now derived from a shared `Watch.serviceDueDate` computed property so
  `MaintenanceView` and `NotificationManager`'s reminder scheduling can never disagree on the due date.
  `NotificationManager.scheduleServiceDueReminder(for:)`/`cancelServiceDueReminder(for:)` are called from
  `AddWatchView.save()` (create + edit), `AddServiceRecordView.save()` (logging a service resets the
  3-year clock), and both delete paths (`WatchDetailView`'s toolbar Delete, `VaultGridView`'s context-menu
  Delete); `ContentView` requests notification authorization and reschedules every watch once at launch.
  Reminder identifiers are derived from `watch.persistentModelID` rather than a new stored field — no
  schema change was needed for this feature. `DataBackupManager.swift` (also static-only, no view) provides
  the Data section's four operations: `exportWatchesCSV`/`importWatchesCSV` (a flat CSV of just `Watch`'s
  own fields, via a small hand-rolled CSV encoder/parser — no third-party dependency), and
  `exportEncryptedBackup`/`importEncryptedBackup` (a `Codable` snapshot of the entire collection — watches
  with their embedded service records/wear logs/provenance docs, straps linked back to a watch by array
  index within the same payload, wishlist items, and the wrist profile — JSON-encoded then sealed with
  CryptoKit `AES.GCM` using a key derived from a user-entered passphrase via `SHA256`, no PBKDF2/salt).
  Restore is additive (inserts alongside the existing collection) rather than replace-all — see the
  monetization plan's Section 9 for that as an open decision. `OfficialServiceDirectory.swift` is a
  non-SwiftData Swift literal (`OfficialServiceDirectory.contacts: [OfficialServiceContact]`), not a
  `@Model` — it's bundled read-only reference data, so it doesn't belong in the schema, and
  `OfficialServiceContact.id` is the `brand` string (not a fresh `UUID()`) so identity stays stable across
  re-renders. `ServiceContactOverride` is the `@Model` that lets a user edit one of those bundled entries —
  keyed by `brand`, one row per edited contact, deleted entirely on "Reset to Default" rather than storing
  an empty/default row; `ServiceCentersView` merges base + override into a private `EffectiveOfficialContact`
  before displaying. `CustomServiceCenter` is the separate `@Model` for user-added (not manufacturer-sourced)
  service centers. `Watch` also has an optional `referenceNumber`. `Strap` has optional
  `name`, `lengthMM`, and `notes` fields plus a `summary` computed property (`"name · material · width mm"`,
  name omitted if unset) used consistently in pickers/labels — use `strap.summary` rather than re-deriving
  that string. `ProvenanceDoc.fileData` is `@Attribute(.externalStorage)`, same pattern as
  `Watch.photoData`, so large PDFs/images don't bloat the SwiftData store file. `AddWatchView`'s save action
  requires case diameter, lug-to-lug, and lug width to all be positive (not just brand/model non-empty), and
  now doubles as the edit flow via an optional `watchToEdit: Watch?` init param — `WatchDetailView`'s Edit
  button reopens it pre-filled. `AddWatchView`'s photo picker is `PhotosPicker` on iOS but a native
  `.fileImporter` on macOS (PhotosPicker there only browses the macOS Photos library, not arbitrary Finder
  files); `AddProvenanceDocView` uses `.fileImporter` with `[.pdf, .image]` on both platforms since documents
  aren't photos. `Entitlements` drives all feature gating (`isLifetimeUnlocked`, `subscriptionStatus`); the
  UI reads it via `@Query` but never writes it directly — writes only happen from `PurchaseManager`'s
  StoreKit transaction listener and its `reconcileEntitlementsOnLaunch()`/`purchase()`/`restorePurchases()`
  methods, per Section 2.2. When adding new `@Model` types, register them in the `Schema([...])` array in
  `Horology_Vault_App.swift`.
- **Test frameworks:** unit tests (`Horology VaultTests/`) use the new **Swift Testing** framework
  (`import Testing`, `@Test`, `#expect`), not XCTest. UI tests (`Horology VaultUITests/`) use XCTest/XCUITest.
  Match whichever framework the target file already uses. `FitCalculatorTests.swift`, `EntitlementsTests.swift`,
  and `WatchModelTests.swift` cover the Phase 9 priorities (Fit Calculator math, Entitlements/PurchaseManager
  gating, `Watch` service-due/cascade-delete invariants) against in-memory `ModelContainer`s — follow that
  pattern for new model-layer tests rather than hitting the real on-disk store. `LearnHubContentTests.swift`
  guards the Learn Hub cross-link instead of business logic: asserts every `LearnTopic.slug` is unique and
  that `complicationName` values round-trip exactly against `Watch.commonComplications` in both directions,
  so the two lists can't silently drift apart. `FitCalculator.swift` and
  `PurchaseManager.updateEntitlementsRecord(unlocked:in:now:)` exist specifically because their logic used to
  be private/inline and untestable from a separate target — when adding new business logic, consider
  whether it needs the same kind of extraction up front rather than retrofitting it later.
- **Deployment target:** iOS/macOS 26.5 (`IPHONEOS_DEPLOYMENT_TARGET` / `MACOSX_DEPLOYMENT_TARGET = 26.5`),
  Swift 5.0 language mode.
- **Monetization/entitlement design:** see `horology_vault_monetization_plan.md` for the full picture. Key
  point for implementation ordering: V1 is 100% local/offline (no backend), gated only by
  `isLifetimeUnlocked`; subscription-only features (market data, cloud sync, community) and their backend
  services are explicitly out of scope until V1 has traction — don't build backend/network code for those
  screens prematurely. StoreKit 2 testing locally uses `Configuration.storekit` (Edit Scheme → Run →
  Options → StoreKit Configuration) rather than a live App Store Connect product, which still needs to be
  registered separately (same product ID, `com.angelburgos.HorologyVault.lifetime`) before shipping.
