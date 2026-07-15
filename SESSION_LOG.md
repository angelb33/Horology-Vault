# Session Log

## 2026-07-15 — Session 7

### Accomplished this session

- **Cost-per-wear tracking, a follow-up enhancement to Phase 11 (Insights):** `Watch.swift` gained an
  optional `purchasePrice: Double?` and a computed `costPerWear: Double?` (`nil` unless both
  `purchasePrice` is set and `wearLogs` is non-empty, avoiding a divide-by-zero and avoiding implying
  "$0/wear" for an unworn watch). `AddWatchView.swift` gained a currency-formatted entry field.
  `WatchDetailView.swift` shows the raw `purchasePrice` for free (it's just user-entered data) but
  deliberately does NOT show `costPerWear` — that derived insight stays exclusive to the paywalled
  Insights screen by design, a specific product decision confirmed with the user: the point is making
  Insights worth its premium price, so the derived insight shouldn't leak out for free elsewhere. New
  `CostPerWearChartView.swift` (modeled on `WearFrequencyChartView.swift`) is a 5th card in
  `DashboardView.swift`'s Insights screen, automatically covered by Insights' existing paywall (no new
  gating code needed). `DataBackupManager.swift` round-trips `purchasePrice` through the encrypted backup
  but deliberately excludes it from CSV export/import (CSV travels as plaintext wherever it's saved,
  unlike the encrypted-only backup — a comment documents this is intentional, not an oversight). Added 3
  new test cases to `WatchModelTests.swift` covering nil-with-no-price, nil-with-no-wears, and the actual
  division. Build succeeds on both platforms, full test suite passes (40/40).
- **Real bug fix in `PurchaseManager.swift`:** `purchase()` previously silently swallowed a
  `.success(.unverified(...))` StoreKit result (a completed purchase that fails cryptographic
  verification) with zero user feedback — no error, no entitlement write, indistinguishable from every
  other silent-no-op path in the function. Added explicit handling that sets `lastError` with a
  descriptive message. Found while debugging the macOS purchase failure below; it didn't turn out to be
  that bug's root cause, but it closes a real pre-existing silent-failure gap and should stay.
- `CLAUDE.md` and `horology_vault_monetization_plan.md` were updated in-place alongside the feature work
  (established project pattern); also caught and fixed a repeat of last session's date-typo bug — several
  new entries in both docs said "2026-07-16" when the actual date of this work is 2026-07-15 (same class
  of mistake as the "2026-07-16 → 2026-07-15" fix logged in Session 6).
- **Diagnosed (not yet resolved) a macOS-only purchase failure**, the reason this session is closing early
  for a Mac restart. Symptom: "Unlock Full Version" shows a normal-looking purchase sheet on the macOS
  build (from Xcode), but nothing unlocks afterward. After adding the `PurchaseManager` fix above, the
  real thrown error was captured: `ASDErrorDomain Code=825 "No transactions in response"`, thrown before
  the `.success`/`.userCancelled`/`.pending` switch is even reached. Ruled out as an app-code bug via
  direct verification on this machine: product IDs match exactly between `PurchaseManager` and
  `Configuration.storekit`; no duplicate `Entitlements` rows in the on-disk SwiftData store (checked via
  `sqlite3` against the real container path); all `Configuration.storekit` error-simulation flags
  (`_failTransactionsEnabled`, `_storeKitErrors`, `_askToBuyEnabled`) are off; Debug → StoreKit → Manage
  Transactions shows nothing stuck pending; `reconcileEntitlements()`'s `lastValidatedAt` timestamp is
  fresh, proving it runs and correctly finds "not entitled." Cleared
  `~/Library/Caches/com.apple.storekitagent/Octane/com.angelburgos.HorologyVault/` and fully quit/relaunched
  Xcode — same error persisted. Working theory: macOS StoreKit Testing runs through `storekitagent`, a
  persistent per-user system daemon (unlike iOS Simulator's per-device isolation); this session's heavy
  local-price churn (three price edits, Ask-to-Buy toggled, manual transaction deletion via Manage
  Transactions) may have left the *running* daemon in a bad state a file-cache clear can't reach — only a
  full daemon restart (i.e. a Mac restart) might clear it. Full writeup with all verification steps is now
  in `CLAUDE.md`'s new "Known issue" bullet.
- No feature this session was visually verified in Xcode's Canvas/Simulator by the AI itself — same
  sandbox limitation as every prior session (no Screen Recording/Apple Events/GUI-automation permission;
  confirmed again this session via failed `screencapture`/`osascript`/XCUITest attempts). All verification
  was via `xcodebuild build`/`xcodebuild test`; real UI/purchase-flow verification is deferred to the user.

### Pending / next steps

- **First priority next session: retry the macOS purchase after the Mac restart.** If `ASDErrorDomain 825`
  persists even after a full restart, the recommended fallback (not yet decided with the user) is to
  treat iOS Simulator as the primary target for testing purchase flows going forward, since macOS-native
  StoreKit Testing has proven unreliable this session despite the app's own code being verified correct.
- Cost-per-wear chart and the `PurchaseManager` unverified-result fix are committed as of this session
  close (see commit below) but have not been manually eyeballed in Xcode — same outstanding gap as recent
  phases.
- The two manual non-code steps blocking V1 shipping are unchanged: enabling `Configuration.storekit` in
  the Xcode scheme (already done per CLAUDE.md — verify still true) and registering the real product in
  App Store Connect.
- `horology_vault_monetization_plan.md` Section 5.1's "Built so far" list still predates recent phases in
  its bullet-by-bullet detail (noted again this session, carried over from Session 6) — a full rewrite is
  worth doing next time significant V1 work resumes.
- V2 (subscription tier) remains out of scope, gated on V1 getting real user traction — do not start
  unprompted.

## 2026-07-15 — Session 6

### Accomplished this session

- **Scheduled Backup gating reversal (Phase 12 follow-up):** reversed the launch-day ungated decision —
  `ScheduledBackupManager.performBackupIfDue` now fetches `Entitlements` from the passed-in `ModelContext`
  and bails before touching `UserDefaults`/Keychain/the bookmark if `is_lifetime_unlocked` is false, and
  `SettingsView.scheduledBackupSection` became `@ViewBuilder`, showing a compact locked-state paywall row
  in place of the toggle/folder/frequency/passphrase controls when locked. Manual "Encrypted Backup"/CSV
  export/import stay completely free either way — only the automation layer is gated, same "convenience
  on top of always-free data access" reasoning as Insights. Verified via `xcodebuild build`/`test` (both
  platforms, full suite green).
- **Added the Learn Hub** (Phase 13, not originally in the monetization plan): a free/ungated educational
  section for horology beginners, added from user research + three explicit shape decisions (static Swift
  data, not JSON/remote; broad overview across many categories, not narrow-deep; cross-links back into the
  user's own Vault).
  - An Explore-agent survey preceded planning: confirmed the app is sidebar/`NavigationSplitView`-driven
    (not `TabView`), found `Watch.complications`'s only canonical vocabulary lived in a private array
    inside `AddWatchView.swift`, and identified `OfficialServiceDirectory.swift` as the established
    pattern for bundled static reference data.
  - Extracted `commonComplications` out of `AddWatchView.swift` into `Watch.swift` as
    `static let commonComplications`, shared by both `AddWatchView`'s picker and the new cross-link.
  - Added `LearnHubContent.swift` (`LearnCategory` — 8 cases; `LearnTopic` — slug/category/title/summary/
    body/optional `complicationName`/optional `systemImage`; `LearnHubContent.topics` — 50 static
    articles) and `LearnHubView.swift` (category-grouped searchable list → detail view showing an
    "In Your Vault" cross-link section via `@Query` when a complication topic matches watches the user
    owns, navigating into `WatchDetailView`).
  - Wired a new `.learnHub` case into `ContentView.Section` (icon `book.closed`, right after Vault).
  - Added `LearnHubContentTests.swift`: slug uniqueness, and `complicationName` round-trips exactly
    against `Watch.commonComplications` in both directions.
  - Verified via `xcodebuild build`/`test` on macOS — all green.
  - **UI design pass:** the user explicitly invoked the `ui-designer` subagent, which reviewed the shipped
    files, built a throwaway type-checked (not visually rendered) SwiftUI prototype at a scratchpad path
    without touching production files, and proposed a prioritized list. Implemented the top 3: (1) a
    distinct SF Symbol per topic instead of one icon per whole category (`systemImage`/
    `displaySystemImage` on `LearnTopic`); (2) a typography overhaul on the detail screen (`.largeTitle`
    title, tinted `CategoryChip`, `.lineSpacing(4)`, `.frame(maxWidth: 700)` capped reading width — body
    text was stretching edge-to-edge unreadably on macOS/iPad); (3) `InYourVaultCard` — a tinted bordered
    card with a star icon, ownership count, and real 44pt `WatchThumbnail` photo rows — replacing the
    plain-text cross-link footnote. Also added a small bonus: `ContentUnavailableView.search(text:)` empty
    state for Learn Hub search, matching the existing pattern elsewhere in the app.
  - Hit and fixed one real bug: making `WatchCardView.swift`'s private `platformImage(from:)` non-private
    (to reuse it for `WatchThumbnail`) collided with an unrelated identically-named private function
    already in `AddWatchView.swift` (Swift redeclaration error once exposed module-wide). Reverted
    `WatchCardView.swift` back to `private`; wrote a small self-contained image-decode property directly
    inside `LearnHubView.swift` instead.
  - Re-verified via `xcodebuild build`/`test` — full suite green, including `LearnHubContentTests`.
  - **Bug found by the user post-ship, fixed same day:** the Titanium topic (Materials & Case) had no
    visible icon — it was assigned the SF Symbol name `"feather"`, which doesn't actually exist.
    `Image(systemName:)` fails silently at runtime for an invalid name, so this wasn't caught by
    `xcodebuild build` (a clean build says nothing about whether a systemName string resolves to a real
    symbol). Diagnosed with a standalone Swift script calling
    `NSImage(systemSymbolName:accessibilityDescription:)` for every `systemImage` string used across
    `LearnHubContent.swift` and checking which returned `nil` — confirmed `feather` was the only invalid
    one out of all 50. Fixed by switching Titanium to `"scalemass"` (fits the article — titanium being
    lighter than steel). Rebuilt successfully.
- Updated `CLAUDE.md` and `horology_vault_monetization_plan.md`: added the Learn Hub feature (new
  Architecture bullet, Section 6 Phase 13 entry, Section 5.1/5.2 updates), documented the Scheduled Backup
  gating reversal already reflected in the working tree, and fixed a stray future date typo
  ("2026-07-16" → "2026-07-15", the actual date this work was done) that had crept into both docs.

### Pending / next steps

- Learn Hub has not been manually eyeballed in Xcode's Canvas/Simulator from inside any session (no Screen
  Recording/Apple Events permission in this sandbox, same limitation as Phases 10–12) — the user should do
  a final visual pass in Xcode.
- Remaining `ui-designer` brainstorm ideas not built: a category-grid landing screen (replacing the flat
  list), tappable related-topic footer links (articles already cross-reference each other in prose but
  aren't linked yet), a Watch Anatomy interactive diagram, a movements comparison table, and
  `@AppStorage`-backed read/progress tracking.
- Scheduled Backup's locked-state UI (the compact paywall row) also hasn't been manually eyeballed yet —
  same outstanding gap noted when Phase 12 first shipped.
- `horology_vault_monetization_plan.md` Section 5.1's "Built so far" list still predates Phases 10–13 in
  its bullet-by-bullet detail (only patched with pointer notes this session) — a full rewrite of that
  section is worth doing next time significant V1 work resumes, though Section 6's Phase entries are
  currently the up-to-date source of truth.
- V2 (subscription tier) remains the only scope left in the monetization plan, explicitly gated on V1
  getting real user traction — not to be started unprompted.

## 2026-07-14 — Session 5

### Accomplished this session

- Implemented Phase 9 of the monetization plan's Section 6 ordered plan: **test coverage for the Fit
  Calculator, Entitlements gating, and Watch model invariants** — the last phase of the entire V1 ordered
  implementation plan. **This completes the full V1 local-only feature roadmap: all 9 phases of Section 6
  are now done.** Only V2 (the subscription tier, Section 4/Section 10) remains, and it stays gated on V1
  getting real user traction before starting.
- Work was produced by a `test-writer` subagent running in an isolated git worktree (it has no
  git-commit permission in its sandboxed config), then committed/merged/pushed by hand afterward.
- Added `Horology Vault/FitCalculator.swift`: pulled the fit-check math (`wristWidthMM`, `overhangMM`,
  `fits`) out of `FitDiagramView`'s private computed properties — not unit-testable from a separate test
  target — into a pure `FitCalculator.evaluate(lugToLugMM:wristTopWidthCM:) -> Result` static function.
  `FitDiagramView.swift` now delegates to it via one `fitResult` computed property; rendering/behavior
  unchanged (verified via successful build).
- `PurchaseManager.swift`: extracted the insert-or-update persistence logic out of the private
  `reconcileEntitlements()` into `static func updateEntitlementsRecord(unlocked:in:now:) -> Entitlements`
  (`@discardableResult`), callable directly against an in-memory `ModelContext` without touching StoreKit.
  `reconcileEntitlements()` now just gathers `unlocked` from `Transaction.currentEntitlements` and calls
  this function — no behavior change.
- Added `Horology VaultTests/FitCalculatorTests.swift` (10 tests): exact-fit boundary, watch
  smaller/larger than wrist (verifying overhang amount), zero/negative lug-to-lug and wrist-width edge
  cases, an extreme oversized-watch case.
- Added `Horology VaultTests/EntitlementsTests.swift` (13 tests): `Entitlements` defaults,
  insert-vs-update-in-place reconciliation (no duplicate rows ever created), locking on revoke/refund, the
  UI's `entitlements.first?.isLifetimeUnlocked ?? false` gating read before/after a simulated purchase,
  expired/grace-period `SubscriptionStatus` round-tripping, `PurchaseManager.configure(modelContext:)`
  idempotency — all against an in-memory `ModelContainer`. Live StoreKit calls (`Product.products(for:)`,
  `Transaction.currentEntitlements`, `product.purchase()`) are explicitly not unit-tested since they aren't
  meaningfully testable without Apple's `StoreKitTest`/`SKTestSession` framework — noted as a reasonable
  fast-follow using the existing `Configuration.storekit` file from Phase 8, not done this session.
- Added `Horology VaultTests/WatchModelTests.swift` (13 tests): `Watch.serviceDueDate`/`isServiceDue`
  (fallback to `acquisitionDate` when no `ServiceRecord`s exist, uses most-recent
  `ServiceRecord.datePerformed`, 3-year boundary, due clock resetting after a new service), cascade-delete
  of `ServiceRecord`/`WearLog`/`ProvenanceDoc` (individually and all together), nullify-not-delete of an
  attached `Strap` on watch deletion, standard insert/fetch/update round-trips — all against an in-memory
  `ModelContainer`.
- Total: 33 tests pass (32 new + the original Xcode-scaffold `example()` case). One real bug was caught
  and fixed during the process, but it was in the test-writer's own first-draft test data
  (`watchLargerThanWristOverhangs` had numbers that actually described a smaller-than-wrist watch) — not a
  production code bug. Verified via `xcodebuild ... test` (TEST SUCCEEDED) and a separate `... build` run
  for the app target, both re-run in the main checkout after merging, not just trusted from the subagent's
  isolated worktree run.
- Updated `horology_vault_monetization_plan.md`: Section 5.2's gap list now says "Phases 1–9 ... are
  complete. Nothing remains against this plan's V1 scope" (previously listed "Tests" as the one remaining
  gap); Section 6's Phase 9 entry marked "✅ Done (2026-07-14)" with a full writeup of what was tested and
  the StoreKitTest fast-follow note.
- Updated `CLAUDE.md`: "Project state" opening line now says V1 is "fully built out" (Phases 1-9 all done,
  previously "mostly built out"); the Section 6 phase-tracking sentence now says Phases 1-9 all done /
  nothing remains (previously Phases 1-8 done, only Phase 9 remaining); the "Test frameworks" bullet in
  Architecture now names the three new test files and notes the `FitCalculator`/
  `updateEntitlementsRecord` testability-extraction pattern for future business logic.
- Committed as two commits: `9851ca7` (implementation) and `19d5fd6` (doc updates), both already merged
  to `main` and pushed to `origin/main` before this close-out — verified `git status` clean and
  `HEAD` == `origin/main` at `19d5fd6`.

### Pending / next steps

- **The entire V1 local-only feature roadmap (Section 6, all 9 phases) is complete.** No further V1 work
  is defined in the plan.
- Two manual, non-code steps still remain before shipping (carried over from Phase 8, untouched this
  session): enable `Configuration.storekit` in the Xcode scheme (Edit Scheme → Run → Options → StoreKit
  Configuration) for local purchase-flow testing, and register the real
  `com.angelburgos.HorologyVault.lifetime` product in App Store Connect.
- Fast-follow candidate (not scheduled): full end-to-end StoreKit purchase-flow testing via
  `SKTestSession(configurationFileNamed: "Configuration")`, since live StoreKit calls aren't covered by
  this session's unit tests.
- V2 (subscription tier, Section 4/Section 10 of the plan) is the only remaining scope in the
  monetization plan — explicitly gated on V1 having real user traction first, not to be started
  unprompted.

## 2026-07-14 — Session 4

### Accomplished this session

- Implemented Phase 8 of the monetization plan's Section 6 ordered plan in full: **Entitlements +
  StoreKit 2 (V1 monetization)** — the last local-feature phase before Phase 9 (tests).
- Added `Horology Vault/Entitlements.swift`: the `@Model` from Section 2.2 (`isLifetimeUnlocked: Bool`,
  `subscriptionStatus: SubscriptionStatus` — a new `none`/`active`/`expired`/`gracePeriod` enum,
  `subscriptionExpiresAt: Date?`, `lastValidatedAt: Date?`), registered in the `Schema([...])` array in
  `Horology_Vault_App.swift`. Exactly one row is expected to exist; per Section 2.2's design, the UI only
  ever reads this table via `@Query` and never talks to StoreKit directly.
- Added `Horology Vault/PurchaseManager.swift`: an `@Observable` class (`import Observation`) covering all
  five responsibilities Section 8 spells out — `loadProduct()` (`Product.products(for:)` for the single
  product ID constant `PurchaseManager.lifetimeUnlockProductID =
  "com.angelburgos.HorologyVault.lifetime"`), `configure(modelContext:)` (starts a `Task` listening to
  `Transaction.updates`, guarded so it only starts once), `purchase()` (finishes the transaction and
  reconciles on `.success(.verified(...))`; `.userCancelled`/`.pending` are explicit no-ops, not errors, per
  the plan's spec), `restorePurchases()` (`AppStore.sync()` then reconcile), and
  `reconcileEntitlementsOnLaunch()`/private `reconcileEntitlements()` (walk `Transaction.currentEntitlements`
  and write `isLifetimeUnlocked`/`lastValidatedAt` to the single `Entitlements` row, inserting one if none
  exists). No `Task.detached` anywhere — plain `Task { }` blocks were used throughout to match this
  project's `-default-isolation=MainActor` build setting rather than fighting it.
- Added `Horology Vault/Configuration.storekit`: a local StoreKit Testing configuration (schema version 3.0)
  with one non-consumable product matching the product ID above, priced at $49.99, so the purchase flow is
  testable in Xcode/Simulator without a live App Store Connect record. Two manual, non-code steps remain
  before shipping: (1) enabling this file via Xcode's Edit Scheme → Run → Options → StoreKit Configuration,
  and (2) registering the same product ID for real in App Store Connect — both called out explicitly in the
  plan and `CLAUDE.md` rather than left implicit.
- `Horology_Vault_App.swift` — added `Entitlements.self` to the `Schema([...])` array.
- `ContentView.swift` — added `@State private var purchaseManager = PurchaseManager()`,
  `@Environment(\.modelContext)`, and `@Query private var entitlements: [Entitlements]`; injects
  `purchaseManager` into the environment via `.environment(purchaseManager)`; the existing `.task` block now
  also calls a new private `seedDemoDataIfNeeded()`, then `purchaseManager.configure(modelContext:)`,
  `await purchaseManager.loadProduct()`, and `await purchaseManager.reconcileEntitlementsOnLaunch()`.
  `seedDemoDataIfNeeded()` inserts one sample Watch (a Rolex Explorer, ref. 224270) plus a default
  `Entitlements()` row, but only when both `entitlements` and `watches` are empty — guaranteeing it never
  touches an existing user's real collection, only a truly fresh install.
- `VaultGridView.swift` — added `@Environment(PurchaseManager.self)` and
  `@Query private var entitlements: [Entitlements]`, plus a computed `isUnlocked` property reading
  `entitlements.first?.isLifetimeUnlocked ?? false`. The "Add Watch" toolbar button now has
  `.disabled(!isUnlocked)`. Added a new `unlockBanner` view (shown above the grid whenever `!isUnlocked`)
  with a headline, explanatory line, and an "Unlock Full Version" button calling `purchaseManager.purchase()`
  — the demo-mode gating the plan calls for (read-only demo state with a persistent unlock prompt, not a
  hard paywall). The `#Preview` now injects a `PurchaseManager()` into the environment so it still
  compiles/previews standalone.
- `SettingsView.swift` — added `import StoreKit` (needed for `Product.displayPrice` — a real compile error
  the first time, fixed, not the usual stale-SourceKit noise), `@Environment(PurchaseManager.self)`, and
  `@Query private var entitlements: [Entitlements]`. `purchaseStatusSection` was rewritten from
  static/disabled UI to live: shows "Full Version" (green checkmark) when unlocked or "Demo (Read-Only)"
  (secondary lock icon) when not; when locked, shows an "Unlock Full Version — \(product.displayPrice)"
  button calling `purchaseManager.purchase()`; "Restore Purchase" now actually calls
  `purchaseManager.restorePurchases()` (previously a disabled no-op); an inline red error line appears if
  `purchaseManager.lastError` is set.
- Updated `horology_vault_monetization_plan.md`: Section 6's Phase 8 header marked "✅ Done (2026-07-14)"
  with a full description of the above, calling out the two remaining manual steps and the scope decision
  that only the Vault's "Add Watch" action is gated (not every "+" button app-wide — Straps/Wishlist/Service
  Centers stay open, since the plan's own example only mentions "Add Watch disabled" and a demo user only
  has the one seeded watch to explore anyway). Section 5.1's "Settings" bullet updated from "stubbed
  Purchase section" to "a working Purchase section wired to PurchaseManager"; a new bullet describing
  Entitlements+StoreKit 2 was added. Section 5.2's gap list shrank to just Tests, with the intro line
  updated from "Phases 1–7 ... complete" to "Phases 1–8 ... complete."
- Updated `CLAUDE.md`: "Project state" paragraph, the Architecture section's view-hierarchy bullet, the
  Persistence bullet's schema list, and the "Monetization/entitlement design" bullet all revised in place to
  describe the new Entitlements/PurchaseManager/gating behavior and the Phases 1–8 done / only Phase 9
  remaining split (previously Phases 1–7 done / 8–9 remaining).
- Verified every change with `xcodebuild -project "Horology Vault.xcodeproj" -scheme "Horology Vault"
  -destination 'platform=macOS' build` after editing. One real compile error was hit and fixed (the missing
  `import StoreKit` for `Product.displayPrice`) — final build succeeded (BUILD SUCCEEDED). As in every prior
  session, SourceKit/editor diagnostics repeatedly showed stale "Cannot find type X in scope" errors for
  types that demonstrably compiled fine — known editor-index lag, distinct from the one genuine compile
  error actually fixed this session.

### Pending / next steps

- Only Phase 9 (tests) remains from the monetization plan's Section 6 ordered plan — no automated coverage
  exists for any model/view added since the default Xcode scaffold; prioritize the fit calculator math,
  Entitlements gating logic, and StoreKit purchase flow handling per the plan's own emphasis.
- Two manual, non-code steps before shipping: enable `Configuration.storekit` in the Xcode scheme (Edit
  Scheme → Run → Options → StoreKit Configuration) for local purchase-flow testing, and register the real
  `com.angelburgos.HorologyVault.lifetime` product in App Store Connect.
- The demo-mode gating only disables "Add Watch" in the Vault — Straps/Wishlist/Service Centers "+" actions
  stay open by design (see scope note above); revisit only if that proves too permissive in practice.
- `PurchaseManager`'s error handling surfaces `error.localizedDescription` directly in the UI — fine for V1,
  but may be worth mapping to friendlier copy once real StoreKit error cases are observed in the wild.

## 2026-07-14 — Session 3

### Accomplished this session

- Implemented Phase 7 of the monetization plan's Section 6 ordered plan in full: **Authorized service
  center directory**. (Note: this is the first commit that includes this feature — despite a prior
  same-day session log entry describing it as "not started," no earlier commit for it exists in git
  history, so this entry covers the complete feature build, not just an incremental expansion.)
- Added `Horology Vault/OfficialServiceDirectory.swift`: a bundled, read-only `OfficialServiceContact`
  literal array (root-domain-only contact info — deliberately no phone numbers/addresses, since
  third-party listings for those are frequently stale). Built in two tiers: an initial 16 major
  manufacturers (Rolex, Tudor, Omega, Seiko, Grand Seiko, TAG Heuer, Breitling, IWC, Panerai, Cartier,
  Longines, Citizen, Hamilton, Casio, Hublot, Tissot), then expanded — at the user's explicit request —
  to all ~169 brands listed at thewatchpages.com/brands, from mass-market names down to ultra-niche
  independent ateliers (AKRIVIA, De Bethune, Voutilainen, Urwerk, Greubel Forsey, F.P.Journe, Czapek, and
  many more). The original 16-brand array is untouched; the expansion is a new `additionalContacts: [OfficialServiceContact]`
  array (153 entries) built via a small `contact(_:_:)` helper (name defaults to brand name, notes is one
  consistent generic line) to avoid repeating full initializer boilerplate 153 times. The public `contacts`
  array is the original 16 + `additionalContacts`. Domains were either already confidently known (~52
  well-known brands) or verified one-by-one via web search (~99 independent/niche brands) — never guessed.
  Three brands from the source list were deliberately excluded: Claude Meylan and Emmanuel Bouchet (no
  confident official website found via search) and Purnell (confirmed bankrupt/ceased operating as of
  December 2024, so there's no active support to point users to). Verified final count via `grep -c`: 17
  `OfficialServiceContact(` literal occurrences (16 curated + 1 inside the `contact()` helper) plus 153
  `contact("` call sites = 169 total brands.
- Added `Horology Vault/CustomServiceCenter.swift`: a new `@Model` (name, brand, phone, website, address,
  notes) for user-added service centers, registered in the `Schema([...])` in `Horology_Vault_App.swift`.
  This resolves an open decision noted in the plan — the plan originally scoped this feature as
  manufacturer-only reference content, but a collector's actual trusted service contact is often
  independent, not the manufacturer, so custom entries were added as an explicit (non-scope-creep) ask.
- Added `Horology Vault/ServiceCentersView.swift`: a `.searchable` List with two sections —
  "Manufacturer Support" (the bundled `OfficialServiceDirectory.contacts`, read-only) and "My Service
  Centers" (`@Query`-fetched `CustomServiceCenter`s, "+" toolbar button opening a private
  `AddServiceCenterView` sheet, swipe-to-delete on custom entries only). Search filters both sections by
  brand or name.
- `ContentView.swift` — added `.serviceCenters` as a 6th `ContentView.Section` case (between Maintenance
  and Settings, `wrench.adjustable` icon), routed to the new `ServiceCentersView`.
- Updated `horology_vault_monetization_plan.md`: Phase 7's Section 6 entry marked "✅ Done (2026-07-14)"
  with a description of the two-tier brand growth and the 3 named exclusions with reasons; Section 5.1's
  "Built so far" bullet added for the directory (169 manufacturers); Section 5.2's gap list renumbered
  (service center directory removed, "Phases 1–7 ... complete"); the planned view-hierarchy section (§7)
  gained "Service Centers" sidebar entry and screen description.
- Updated `CLAUDE.md`: "Project state" paragraph now mentions `ServiceCentersView.swift`/
  `OfficialServiceDirectory.swift`/`CustomServiceCenter` and the Phases 1–7 done / 8–9 remaining split; the
  Architecture section's sidebar/view-hierarchy bullets and the Persistence bullet (schema list, plus a new
  paragraph explaining `OfficialServiceDirectory` is a plain Swift literal, not a `@Model`, since it's
  bundled read-only reference data) were revised in place to match.
- Checked `horology_vault_market_research.md` for stale service-center/phase references — none existed, so
  no edit was needed there.
- Verified with `xcodebuild -project "Horology Vault.xcodeproj" -scheme "Horology Vault" -destination
  'platform=macOS' build` after editing — BUILD SUCCEEDED, no new compile errors. The recurring SourceKit
  "Cannot find type X in scope" editor diagnostics are known stale editor-index lag (as in every prior
  session), not real errors.

### Pending / next steps

- Remaining phases from the monetization plan's Section 6: Phase 8 (`Entitlements` model +
  `PurchaseManager` + StoreKit 2 — the app currently has zero purchase gating), Phase 9 (tests — no
  automated coverage exists for any model/view added since the default Xcode scaffold).
- `OfficialServiceDirectory` domains were verified via web search rather than an authoritative source of
  record — worth a periodic re-check for brand acquisitions, site migrations, or domain changes, especially
  among the smaller independent ateliers.
- Claude Meylan, Emmanuel Bouchet, and Purnell are intentionally absent from the directory (no confident
  official site / company ceased operating) — revisit only if better information surfaces.

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
