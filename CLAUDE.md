# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

The Xcode default template has been replaced with the real app, and V1's local-only feature set (Section 1
of the monetization plan) is now fully built out — Phases 1–12 of Section 6's ordered plan are all done, plus
two further features shipped outside that plan's original scope (Phase 13 Learn Hub, Phase 14 Winding Log —
see below). The
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
10–11. Phase 11 (Insights) gained a follow-up enhancement 2026-07-15: a **cost-per-wear chart**
(`CostPerWearChartView.swift`), backed by a new optional `Watch.purchasePrice` and computed `costPerWear`
(see Architecture below) — already covered by Insights' existing paywall, no new gating code needed.
Nothing else remains against
this plan's V1 scope. A feature outside the monetization plan's original scope, **Learn Hub**, was added
2026-07-15: a free/ungated educational section (`LearnHubContent.swift`, `LearnHubView.swift`) covering
watch anatomy, movements, complications, materials, straps, care, buying, and a glossary — 50 static
articles across 8 categories, each with its own SF Symbol, and complication topics cross-link into the
user's own Vault via a shared `Watch.commonComplications` vocabulary (see Architecture below for the
full design and a hard-won SF Symbol lesson). A further round of same-day polish shipped later on
2026-07-15, none of it tied to a new monetization-plan phase number: **Service Center contact fields** —
`ServiceContactOverride` gained optional `phone`/`address`/`secondaryWebsite` (previously just
`name`/`website`/`notes`) and `CustomServiceCenter` (which already had `phone`/`address`) gained
`secondaryWebsite` to match, with `ServiceCentersView`'s edit/add forms and row displays updated
accordingly (see Architecture below) — plain additive optionals, no migration needed, same pattern as
`Watch.purchasePrice`. **A UI design pass**, run via the `ui-designer` subagent, introduced a shared
`SectionHeader.swift` component (centered, `.title2.weight(.semibold)`) that now backs every `Form`/`List`
Section header and `DisclosureGroup` label app-wide — `AddWatchView`, `WatchDetailView` and its nested
sheets, `SettingsView`, `ServiceCentersView`, `WishlistView`, `FitCalculatorView`, `MaintenanceView`,
`LearnHubView` — replacing SwiftUI's default small/uppercase/left-aligned styling (see Architecture below;
`DashboardView`'s `InsightCard` titles were deliberately left alone, since those are card titles rather than
Form section headers). **`VaultGridView`'s toolbar was fixed** for iOS 26 Liquid Glass, where adjacent
`ToolbarItem`s were fusing the sort control and Add button into one shared glass pill (see Architecture
below). **A stray Xcode 16 build warning was cleaned up** — Xcode's synchronized-group project format was
auto-including `Info-iOS-BackgroundTasks.plist` (intentionally merged into Info.plist via a build setting,
not meant to be a Copy Bundle Resources member) as a resource; a
`PBXFileSystemSynchronizedBuildFileExceptionSet` in `project.pbxproj` now excludes it (see Architecture
below). This was unrelated to a separate Simulator launch failure the user hit this session
(`FBSOpenApplicationServiceErrorDomain`/`SBMainWorkspace RequestDenied`) — diagnosed as a stuck
Simulator/launchd daemon state rather than a code bug (the build itself succeeded), fixable by
quitting/relaunching Simulator or, per this machine's documented history of stuck system daemons (see the
StoreKit known issue below), a full restart. **The first-launch demo watch was changed** from a real "Rolex
Explorer" to an explicitly fictional "Sample Brand" / "Example Watch" placeholder in
`ContentView.seedDemoDataIfNeeded()`, so a fresh install no longer implies the seeded sample is a real product.
All of the above builds clean on both macOS and iOS Simulator (`iPhone 17` this session) with
zero warnings; none touched business logic, so no new tests were added, and none was visually confirmed in
Xcode's Canvas/Simulator from inside this session (same sandbox limitation noted throughout this file).
(Note, 2026-07-17: this machine no longer has `iPhone 16` installed — only `iPhone 17`+ simulators — so the
Common Commands section below now points at `iPhone 17` instead.)
A further feature was added and shipped 2026-07-17, outside the monetization plan's original V1 scope, same
pattern as Learn Hub: **Phase 14, Winding Log / Power Reserve tracking** — a mechanical-watch winding
tracker. `Watch.swift` gained a `MovementType` enum (`.manual`/`.automatic`/`.quartz`), optional
`movementType`/`powerReserveHours` fields, a cascade-delete `windLogs` relationship, and computed properties
(`lastWoundDate`, `lastPoweredDate`, `powerReserveExpiresAt`, `isPowerReserveDepleted` — see Architecture
below for the automatic-vs-manual branching). A new `WindLog.swift` model (mirrors `WearLog`) was registered
in the `Schema([...])` array in `Horology_Vault_App.swift`. `AddWatchView` gained a "Movement" section
(type picker + conditional power-reserve-hours field), `WatchDetailView` gained a "Power Reserve" section
(Wind Watch button, relative-date status text, wind history), and `WatchCardView` gained a red
"gauge.with.needle" badge (SF Symbol existence verified via a throwaway `NSImage` check first, continuing
this project's established practice after the Learn Hub "feather" incident) for depleted watches, opposite
corner from the existing orange service-due wrench badge. Quartz movements deliberately got no new schema —
a battery swap is just a normal Service Record with `serviceType` "Battery Replacement", reusing existing
infra rather than building a parallel system. 10 new tests were added to `WatchModelTests.swift` covering
the manual/automatic/quartz `lastPoweredDate` branching and `WindLog` cascade-delete (the existing
"all relationship kinds" cascade test was extended to include `WindLog`). Both macOS and iOS Simulator
(`iPhone 17`) builds are clean and the full unit test suite passes; same longstanding sandbox limitation as
the rest of this app's UI work, this hasn't been visually confirmed in Xcode. `ContentView.seedDemoDataIfNeeded()`'s
first-launch sample watch was updated to `movementType: .automatic, powerReserveHours: 42` (a standard
automatic spec) so a fresh install's demo watch actually demonstrates the feature. `VaultGridView`'s
long-press quick-action menu on watch cards was also revised this session: "Delete" was removed from it
(delete already existed correctly via `WatchDetailView`'s toolbar with its own confirmation dialog, so this
was a straight removal of dead-end duplicate UI, including the now-unused `watchPendingDeletion` state and
its `confirmationDialog`), and a "Wind Watch" quick action was added in its place, shown only for
manual/automatic watches. Two smaller, unrelated fixes shipped the same session: **sidebar icon tinting** —
`ContentView`'s sidebar `Label`s now tint just their icon (not the row text) with the user's chosen accent
color, matching the Apple Reminders/Notes pattern (an earlier attempt at tinting the whole sidebar List
background was tried at the user's request, then reverted per feedback) — and a **Learn Hub accent-color
bug fix**: `LearnHubView.swift`'s `LearnTopicRow`/`CategoryChip`/`InYourVaultCard` were hardcoded to
`Color.accentColor` (a fixed asset-catalog color that does not track `.tint()`), so Learn Hub's icons were
silently stuck on default blue regardless of the user's Settings accent-color choice; fixed by reading
`@AppStorage("accentColorOption")` directly, the same pattern `ContentView`/`SettingsView` already use.
**Also this session, still UNVERIFIED as of 2026-07-17 — needs a user retest before being treated as
resolved:** a real appearance bug where switching Appearance from Light to System (with the Mac itself in
Dark mode) left some surfaces, notably the sidebar, stuck showing light-mode styling instead of following
the system. Two fix attempts (explicitly setting `NSApp.appearance` in a new `.onChange(of:
colorSchemePreference, initial: true)`, then splitting `ContentView.body` so the `NavigationSplitView` lived
in a `splitView` computed property carrying `.id(colorSchemePreference)` to force a full subtree rebuild)
were both in place together and the user retested and confirmed the bug **still happened**. Root cause
found afterward: `.preferredColorScheme(nil)` itself (the `.system` case's mapping) has a long-standing
SwiftUI/AppKit bug on macOS where `nil` doesn't reliably re-enable system-appearance tracking once a window
has had an explicit override — the stuck state lives on the `NSWindow`/its vibrancy material, not the
SwiftUI view tree, which is why neither prior fix could reach it. **Third fix, also still unverified:**
`ContentView` now never passes `nil` to `.preferredColorScheme` on macOS — a new `SystemAppearanceObserver`
(`@Observable`, KVO on `NSApplication.effectiveAppearance`, defined at the bottom of `ContentView.swift`)
tracks the real OS appearance and `ContentView.effectiveColorScheme` resolves `.system` to that concrete
value instead; the now-pointless `.id(colorSchemePreference)` rebuild was removed. See the "Known issue"
bullet near the end of this file for full detail — **treat this as unverified until the user retests.**
Separately, a V2 CloudKit Sync phase (a Phase 15 candidate, tentatively) was
discussed and scoped in detail this session but **not implemented** — no code was written. Worth
referencing if picked up later: it needs manual iCloud capability setup in Xcode (no `.entitlements` file
exists in this project yet), schema changes across most `@Model`s (CloudKit requires default values on every
property), and `Entitlements` should stay in a separate, non-CloudKit-synced `ModelConfiguration` to avoid a
duplicate-row risk across multiple devices sharing one iCloud account.
A follow-up to the Winding Log feature shipped later, still 2026-07-17: Insights gained a 6th trend card,
**Power Reserve** (`PowerReserveChartView.swift`, modeled directly on `ServiceStatusChartView.swift`) —
a bar chart of hours remaining (or overdue, shown red) until each manual/automatic watch's mainspring runs
down, derived straight from the already-tested `Watch.powerReserveExpiresAt`. Quartz watches and any watch
missing a `movementType`/`powerReserveHours` spec are excluded from the chart, same scope cut as the rest of
Winding Log. Wired into `DashboardView` after the Cost per Wear card; inherits the existing Insights paywall
automatically, no new gating code, same pattern as Cost per Wear's addition. No new tests were added — the
chart is pure presentation over `powerReserveExpiresAt`/`isPowerReserveDepleted`, which the Phase 14 test
batch already covers. Both platforms build clean.
Later the same day, a deliberate monetization-strategy shift shipped: **both local reminder notifications
(Service Due and a new Wind Reminder) are now gated behind the lifetime unlock**, reversing Service Due's
previous free status. Decided in conversation with the user, reasoning: with the app still pre-launch (no
installed base to break trust with), a push notification is a far more universal conversion trigger than
Insights/Scheduled Backup, since it reaches every user at the moment their watch actually needs attention,
not just the subset who care about analytics or backups — while the free tier keeps every core action (add
watches, log service/wear/wind, and the in-app status badges/text that already surface the same "due" or
"depleted" signal for free) so it never feels crippled. `Watch` gained one more plain additive optional,
`windReminderLeadTimeHours` (a user-entered "remind me N hours before the power reserve runs out"), and a
computed `windReminderDate` (`powerReserveExpiresAt` minus that lead time, `nil` if either input is
missing — 3 new tests in `WatchModelTests.swift`). `NotificationManager` was restructured to take gating as
an explicit `isUnlocked: Bool` parameter on every schedule call rather than querying SwiftData itself
(matching how `ScheduledBackupManager` already takes its gating input from the caller) — `cancelServiceDueReminder`/
new `cancelWindReminder` stay ungated since cancelling is never something to gate. `scheduleWindReminder`
mirrors `scheduleServiceDueReminder`'s structure but with hour/minute trigger granularity (Service Due only
needed year/month/day) since a wind reminder's lead time is hours, not years. Every existing call site
(`ContentView`, `AddWatchView`, `WatchDetailView`'s delete/Wind Watch/Log Today actions, its nested
`AddServiceRecordView`, `VaultGridView`'s own quick-action equivalents of Wind Watch/Log Today, and
`SettingsView`'s encrypted-backup-restore path) now reads its own `Entitlements`
`@Query` and passes `isUnlocked` through — see the Architecture section's Persistence/Notifications bullets
for the full call-site list. `ContentView` also gained `.onChange(of: isUnlocked, initial: true)` calling
`NotificationManager.rescheduleAll`, replacing the old one-shot `.task` call, so a mid-session purchase
activates both reminders immediately rather than requiring a relaunch. `AddWatchView`'s Movement section
gained a "Wind Reminder" hours field next to Power Reserve (same manual/automatic-only visibility,
same `effectiveWindReminderLeadTimeHours` clear-on-movement-switch pattern as `effectivePowerReserveHours`)
— deliberately left editable and unlocked-data-safe regardless of entitlement status (only the *notification
firing* is gated, not data entry, so a free user's input isn't lost if they later unlock), with a locked-state
footer note (plain text, not an actionable purchase button — that flow already lives in Settings/Insights)
pointing them at Settings to unlock. `WatchDetailView`'s "Wind Watch" button and "Log Today" (wear) button —
and `VaultGridView`'s own duplicate quick-action versions of both, reached from a watch card's context
menu — all now reschedule the wind reminder after logging, since either action can push
`powerReserveExpiresAt` (and therefore `windReminderDate`) forward — wearing an automatic recharges its
mainspring too, per `Watch.lastPoweredDate`; this reschedule is a harmless no-op for manual/quartz watches
on the wear path. Both platforms build clean and the full unit test suite passes.
A same-day follow-up made the reminders discoverable and configurable, prompted by the user pointing out the
Service Due reminder was invisible (no UI at all) and its interval wasn't adjustable. **`SettingsView` gained
a new "Reminders" section** (placed between Data and Scheduled Backup, same locked/unlocked
`@ViewBuilder`-branched pattern as `scheduledBackupSection`) with a "Service Due Reminders" toggle, a
"Service Interval" picker (1–10 years), and a "Wind Reminders" toggle — the first dedicated, easy-to-find
home for reminder settings; previously the only surfacing was a footer note buried in `AddWatchView`'s
Movement section (which still exists, unchanged, for in-context awareness at the point of entering a wind
lead time). The Service Due interval, previously hardcoded to 3 years directly in `Watch.serviceDueDate`,
is now a `UserDefaults`-backed setting (key `NotificationManager.serviceIntervalYearsKey`,
**default changed to 5 years** per the user's explicit request) — `Watch.serviceDueDate` reads it directly
from `UserDefaults.standard` rather than taking it as a parameter, since `Watch` is a SwiftData model and
can't hold `@AppStorage`; this is the same UserDefaults-direct-read pattern `ScheduledBackupManager`
established for its own settings, now extended to a model computed property for the first time. The two new
enable/disable toggles are read the same way, gating inside `NotificationManager.scheduleServiceDueReminder`/
`scheduleWindReminder` (`UserDefaults.standard.object(forKey: ...) as? Bool ?? true` — on by default,
consistent with the reminders already existing before this toggle was added). All three new keys —
`isServiceDueReminderEnabledKey`, `isWindReminderEnabledKey`, `serviceIntervalYearsKey`, plus
`defaultServiceIntervalYears = 5` — live as `static let`s on `NotificationManager`, mirroring exactly how
`ScheduledBackupManager` centralizes its own UserDefaults keys. `SettingsView` reschedules every watch's
reminders whenever any of the three settings change, via a single combined `reminderSettingsSignature`
string `.onChange` rather than three separate `.onChange` modifiers — stacking three more modifiers onto
`SettingsView.body`'s already-long chain hit Swift's "unable to type-check this expression in reasonable
time" error, which combining into one `.onChange` didn't fully fix either; the actual fix was splitting
`body`'s modifier chain into three separate `some View`-returning pieces (`formWithNavigationModifiers`,
`withFileImportExportHandlers(_:)`, `withPassphraseAndStatusAlerts(_:)`, the latter two `@ViewBuilder`
functions taking the accumulated content as a parameter) so the type checker solves each independently
instead of one combinatorially large nested expression — worth remembering as the general fix if this error
recurs elsewhere in this file. `WatchModelTests.swift`'s existing service-due tests were updated from
hardcoded "3 years" expectations to 5, and a new test (`serviceDueDateUsesConfiguredInterval`) verifies the
UserDefaults override actually works, bracketing the key with save/restore via `defer` so it can't leak
state into other tests (no test in this project had touched `UserDefaults` before this). Both platforms
build clean and the full unit test suite passes.
Immediately after, per explicit user feedback that a single global interval wasn't enough, **reminders
gained per-watch overrides on top of the Settings master switches**, same day. `Watch` gained three more
plain additive optionals: `serviceIntervalYears: Int?`, `isServiceDueReminderEnabled: Bool?`, and
`isWindReminderEnabled: Bool?` — deliberately not added as `init(...)` parameters like
`windReminderLeadTimeHours` was, since they're only ever set later via direct `@Bindable` mutation from
`WatchDetailView`'s new Reminders section, never at watch-creation time. `Watch.serviceDueDate` now checks
three layers in order: the watch's own `serviceIntervalYears`, then the Settings-level `UserDefaults`
default, then `NotificationManager.defaultServiceIntervalYears` — one new test
(`serviceDueDateUsesPerWatchOverrideOverGlobalDefault`) confirms the per-watch value wins.
**`NotificationManager.scheduleServiceDueReminder`/`scheduleWindReminder` gained a third guard each**,
checking `watch.isServiceDueReminderEnabled ?? true` / `watch.isWindReminderEnabled ?? true` after the
existing `isUnlocked` and app-wide-master-switch guards — this is a strict AND, not a fallback, matching
the user's explicit spec: "if [the global switch is] disabled then all other individual reminders will be
disabled, if it is enabled again the individual settings will be respected." **`WatchDetailView` gained a
new Reminders section**, placed immediately after Overview (first thing visible on the Workbench, per the
user's ask to make reminders "easy to identify" rather than the previous AddWatchView-footer-only
surfacing) — a "Service Due Reminder" toggle, a "Service Interval" picker (1–10 years, same range as
Settings'), and a "Wind Reminder" toggle (shown only for manual/automatic watches, mirroring the existing
Power Reserve field's visibility rule). Each control is backed by a computed `Binding<Bool>`/`Binding<Int>`
whose `set` both writes the optional model property and immediately calls
`NotificationManager.scheduleServiceDueReminder`/`scheduleWindReminder` for that one watch — deliberately
not `.onChange`-based, both to avoid the exact type-checker blowup just fixed in `SettingsView` and because
`logWindNow()`/`logWearToday()` already established "mutate then directly call NotificationManager" as this
view's pattern. Locked (not-yet-unlocked) state shows a plain `Label` pointing at Settings, no purchase
button — matching `AddWatchView`'s locked footer, not `SettingsView`'s full paywall section, since
`WatchDetailView` doesn't have `PurchaseManager` injected and this isn't meant to be a primary conversion
surface. `SettingsView`'s Reminders section footer was reworded to state the AND-gate relationship
explicitly and point at each watch's own Reminders section; its interval picker was relabeled "Default
Service Interval" to reflect that it's now a fallback, not the only source of truth. Both platforms build
clean and the full unit test suite passes.
One more same-day follow-up made the AND-gate relationship visible, not just documented in a footer:
**`WatchDetailView`'s per-watch reminder controls now visually grey out when the matching app-wide master
switch is off.** Two read-only `@AppStorage` properties were added
(`isServiceDueReminderEnabledGlobally`/`isWindReminderEnabledGlobally`, same keys
`NotificationManager.isServiceDueReminderEnabledKey`/`isWindReminderEnabledKey` that `SettingsView` writes —
`WatchDetailView` only reads them, Settings still owns writing) and applied via `.disabled(...)` to the
Service Due toggle + Service Interval picker (together, since both are meaningless once Service Due is
globally off) and separately to the Wind Reminder toggle, since the two master switches are independent.
The Reminders section's footer was also made conditional — it now names whichever specific master switch is
actually off (Service Due, Wind, or both) instead of a static generic sentence, so the message only appears
when relevant and says exactly what's overriding this watch's settings. Pure UI/visibility change, no new
model or scheduling logic, so no new tests; both platforms build clean and the full suite still passes.
A new premium-only feature shipped the same session, brainstormed with the user first (visual style and
free/paid behavior were both explicit design questions, not assumed): **a minimalist power reserve bar on
each Vault grid card**, gated behind the lifetime unlock. `Watch` gained a computed
`powerReserveRemainingFraction: Double?` (1.0 = just wound/worn, clamped to 0.0 rather than going negative
once depleted; `nil` for the same reasons `powerReserveExpiresAt` is nil — quartz, unset movement, or no
power-reserve spec — 4 new tests in `WatchModelTests.swift`). `WatchCardView.swift` gained a private
`PowerReserveBarView` — a thin `Capsule`-based fuel-gauge bar under the photo, color-coded green
(`>=0.4` remaining) → yellow (`>=0.15`) → red (`<0.15`) — and its own `@Query private var
entitlements: [Entitlements]`/`isUnlocked` (a self-contained pattern, since `WatchCardView` previously took
only a `watch:` param and had no SwiftData awareness of its own). **Free-tier behavior was an explicit
design decision, not an assumption:** the existing red `gauge.with.needle` "depleted" badge (previously
ungated, shown to every user) still shows for locked users exactly as before — only unlocked users with a
trackable power reserve see it swapped for the new bar (`showsPowerReserveBar = isUnlocked &&
watch.powerReserveRemainingFraction != nil`), so no free functionality was taken away in the process of
adding this paid one, consistent with how every other paid feature in this app was scoped. `VaultGridView`'s
existing preview `.modelContainer` already included `Entitlements.self` from earlier work;
`WatchCardView`'s own standalone `#Preview` needed the same addition since it now queries that type too.
Both platforms build clean and the full unit test suite passes.
A small validation fix followed: **`AddWatchView` now rejects a Wind Reminder lead time that's equal to or
greater than Power Reserve.** A lead time that long would compute a `windReminderDate` at or before the
watch was last wound/worn — i.e. the "reminder" would fire at the same moment as, or after, the watch is
already depleted, defeating the point of a warning. `canSave` gained a new `isWindReminderLeadTimeValid`
guard (vacuously true unless movement is manual/automatic and both values are set, matching the
`effectivePowerReserveHours`/`effectiveWindReminderLeadTimeHours` clearing pattern's scope), and the
Movement section's footer shows a red inline warning when it fails, alongside (not replacing) the existing
locked-reminders footer note. Left untested and inline in the View, same as `canSave`'s other checks
(`caseDiameterMM > 0`, etc.) — simple enough not to warrant the kind of extraction `FitCalculator`/
`PurchaseManager.updateEntitlementsRecord` got for their more complex logic. Both platforms build clean.
Insights gained a 7th card the same session: **Depleted Watches** (`DepletedWatchesChartView.swift`), a bar
chart scoped to only the manual/automatic watches currently out of power, showing whole days since each
one's `powerReserveExpiresAt` — deliberately narrower than the existing Power Reserve card (which plots
every trackable watch's hours remaining/overdue): this one is a focused "what needs winding right now" view.
Backed by a new `Watch.daysSincePowerReserveDepleted: Int?` (`nil` unless `isPowerReserveDepleted`, 3 new
tests in `WatchModelTests.swift`). Empty state uses a positive "All Watches Powered" /
`checkmark.circle` framing rather than the usual `ContentUnavailableView` negative-framing default, since an
empty list here is the good outcome, not a missing-data problem. Wired into `DashboardView` after Power
Reserve; inherits the existing Insights paywall automatically, same as every other card. Both platforms
build clean and the full unit test suite passes.
The same session, after a web research pass on what comparable watch-collection apps and horology/insurance
sources commonly track (WristTrack, iCollect Everything, watch-reference-number and insurance guides — see
chat history for sources), **10 new collector/insurance detail fields were added to `Watch`**, all plain
additive optionals (same zero-migration-risk pattern as every prior field): `serialNumber`/`caliber`/
`caseMaterial`/`dialColor` (free text), `waterResistanceMeters` (Int), `boxAndPapersStatus` (new
`BoxAndPapersStatus` enum: Full Set/Watch Only/Box Only/Papers Only), `condition` (new `WatchCondition`
enum: New/Excellent/Good/Fair/Poor), `warrantyExpirationDate`/`appraisalDate` (Date), `insuredValue`
(Double, distinct from `purchasePrice` — what it's insured for vs. what was paid). Explicitly **not**
added: live/tracked market value, since that's the monetization plan's V2 "Market Value" feature,
deliberately deferred until the subscription tier ships — everything added here is static, user-entered
data that fits V1's local-only model. All 10 were also added to `Watch.init(...)` (edited via
`AddWatchView`, same as `purchasePrice`/`movementType`/etc., unlike the reminder-toggle fields from earlier
in this file which are only ever set post-construction). `AddWatchView` gained two new sections,
**Specifications** (caliber, case material, dial color, water resistance) and **Condition & Documentation**
(condition, box & papers, warranty expiration, insured value, appraisal date) — the latter's two optional
dates use a `Bool` "has a value" toggle paired with a concrete `Date` `@State`, since `DatePicker` can't
bind to `Date?` directly (`effectiveWarrantyExpirationDate`/`effectiveAppraisalDate` computed properties
resolve the pair to `nil` when the toggle is off, mirroring the existing
`effectivePowerReserveHours`-style clearing pattern). Serial Number was added to the existing Details
section, next to Reference Number. `WatchDetailView` gained matching read-only **Specifications** and
**Condition & Documentation** sections, each entirely hidden (not just an empty card) when nothing in that
group is set, unlike `AddWatchView` which always shows the fields ready for entry.
**A real pre-existing data-loss bug was found and fixed while wiring these fields into the encrypted
backup**: `DataBackupManager.swift`'s `WatchBackup` Codable DTO was missing not just these 10 new fields but
several already-shipped ones too — `movementType`, `powerReserveHours`, `windReminderLeadTimeHours`,
`serviceIntervalYears`, both reminder-enabled toggles, and the entire `windLogs` relationship (no
`WindLogBackup` existed at all) — meaning a restore from encrypted backup was silently dropping all of that
data despite the feature being documented as capturing "the entire collection." Fixed by adding every
missing field to `WatchBackup` (plus a new `WindLogBackup` struct) and wiring both `exportEncryptedBackup`
and `importEncryptedBackup` to round-trip all of it; `serviceIntervalYears`/`isServiceDueReminderEnabled`/
`isWindReminderEnabled` are set as post-`init` assignments on import, matching how they're only ever set
post-construction elsewhere in the app (see the reminder-gating paragraphs earlier in this file). A new
`DataBackupManagerTests.swift` (this project's first test coverage of the backup/restore feature at all —
previously only `ScheduledBackupManagerTests` tested the due-date math, not the actual encrypt/decrypt/
encode/decode round trip) has one test, `encryptedBackupRoundTripPreservesAllWatchFields`, asserting every
`Watch` field plus a `WindLog` entry survives an export→import round trip — this exists specifically so the
gap can't reopen unnoticed if a future field is added to `Watch` without a matching `WatchBackup` update.
CSV export/import remains deliberately unchanged and still covers only `Watch`'s own flat fields (brand,
model, reference number, complications, measurements, acquisition date) — same "portability format, not a
full backup" scope it already had, unaffected by any of this.
Before implementing, the migration-guardian agent was used proactively (per this file's own stated
practice) to review the 10-field schema change. Verdict: safe additive change, all ten properties correctly
optional, both new enums correctly `Codable` in both the SwiftData and backup-DTO contexts, and it
independently re-ran `DataBackupManagerTests` to confirm the round trip. It flagged two minor,
non-blocking notes: (1) `WatchBackup`'s array fields (`windLogs`, `serviceRecords`, etc.) are non-optional
in the Codable DTO, so a hypothetical backup file missing one of those keys entirely would fail to decode
rather than defaulting to empty — deliberately left as-is, since the app is pre-launch and no such file can
exist yet; revisit if this ever becomes a real forward-compatibility concern post-launch. (2) A cosmetic
guard-consistency issue in `WatchDetailView.specificationsSection`, which was fixed (its outer visibility
check now uses the same `?.isEmpty == false` predicate as the inner rows, matching `overviewSection`'s
existing pattern, instead of a plain `!= nil` that could theoretically show an empty section — unreachable
today since `save()` already nils out empty strings, but worth being consistent). The agent also created an
unrequested `SCHEMA_CHANGELOG.md`; removed, since its content duplicated this file and a second doc that
has to be kept in sync wasn't wanted.
Both platforms build clean and the full unit test suite passes.
Immediately after, from a user brainstorm session, the first of three checklist items was built the same
day: **out-for-maintenance tracking** — a watch checked in at a service center, distinct from Service
History (which logs completed work). `Watch` gained three more post-`init`-only optional fields (same
reasoning as `serviceIntervalYears`/the reminder toggles: set later via UI action, never at creation time):
`maintenanceDropOffDate`/`maintenanceExpectedPickupDate`/`maintenanceNotes`, plus a computed
`isOutForMaintenance` (`maintenanceDropOffDate != nil` — 2 new tests). `WatchDetailView` gained a
**Maintenance** section (placed right before Service History) showing either a "Drop Off for
Maintenance…" button (opens a new private `DropOffForMaintenanceView` sheet — drop-off date, an optional
expected-pickup date using the same toggle-pairs-with-concrete-`Date` pattern as the collector-detail
fields' optional dates, and free-text notes) or, once out, the drop-off/pickup/notes readout plus a "Mark
Picked Up" button. Picking up **clears the three fields and immediately opens the existing Log Service
sheet** (`isLoggingService = true`) — picking a watch up from maintenance is usually the moment to record
what was actually done, so the flow hands off directly rather than making the user separately remember to
log it. A third reminder type, **Pickup Reminder**, was added to `NotificationManager`
(`schedulePickupReminder`/`cancelPickupReminder`, folded into `rescheduleAll`) — deliberately simpler than
Service Due/Wind: gated behind `isUnlocked` only, no app-wide master switch or per-watch toggle, since
unlike those two (recurring, always-on settings) this is a one-off appointment reminder that only exists
while a watch is actually checked in. `WatchCardView` gained a blue `shippingbox.fill` badge (verified to
exist via the established `NSImage`-check practice) that **supersedes** the orange service-due wrench badge
when a watch is out for maintenance — showing both would be redundant, since a watch already at the shop
doesn't need a "you should service this" nag. `MaintenanceView` gained a new "Out for Maintenance" section
(above Service Due, watches sorted most-recently-dropped-off first) via a new `OutForMaintenanceRow`; the
existing Service Due / Up to Date filters were updated to exclude out-for-maintenance watches so a watch
doesn't appear in two buckets at once. `DataBackupManager`'s `WatchBackup` DTO was extended with the three
new fields immediately, applying the lesson from the gap found earlier in this same session rather than
letting it reopen — the existing round-trip test was extended to cover them (now also asserting
`isOutForMaintenance == true` post-restore) instead of adding a separate test. Both platforms build clean
and the full unit test suite passes.
`VaultGridView` gained a `.searchable` search bar the same day (brand/model/reference number/serial
number, case-insensitive `localizedCaseInsensitiveContains`), same pattern `LearnHubView`/
`ServiceCentersView` already established — `ContentUnavailableView.search(text:)` for a no-results state,
distinct from the existing "No Watches Yet" empty-collection state. Pure UI filtering over already-fetched
`@Query` results, no new model logic, so no new tests, matching how `LearnHubView`'s search isn't unit
tested either. Both platforms build clean.
Right after, the user flagged (with a screenshot) that Vault grid cards looked non-uniform and would get
worse as more watches were added. First pass (`.lineLimit(2, reservesSpace: true)` on the model-name `Text`)
addressed text-wrapping height variance but wasn't sufficient — the `ui-designer` subagent was consulted
(per the user's explicit request) and diagnosed two live contributors, both fixed in `WatchCardView.swift`:
(1) the power-reserve bar's `if showsPowerReserveBar { ... }` conditionally added/removed an entire 12pt
element (4pt bar + 8pt `VStack` spacing), and since `LazyVGrid` rows share height across all cells in that
row, one card without a bar sitting next to cards with one grew that whole row unevenly — fixed by always
reserving a 4pt-tall slot when `isUnlocked` (an empty `ZStack` when the current watch has no bar to show),
gated on `isUnlocked` specifically so free users — who never see a bar on any card — don't get dead space
reserved for a feature they can't see; (2) the photo/placeholder's `.aspectRatio(1, contentMode: .fit)` was
applied directly to flexible content (`SmartCroppedImage`'s `GeometryReader`, or the placeholder
`RoundedRectangle`), which meant the square's size was derived from whatever leftover space the row's
`VStack` offered — when row heights varied for any reason (contributor 1, or anything in the future), the
photo silently resized/shifted along with it. Fixed by decoupling the photo from card content entirely: a
new `photoSquare` computed property wraps `Color.clear.aspectRatio(1, contentMode: .fit)` (a square whose
size comes purely from the column width the grid offers, never from sibling content) with `.overlay {
photoContent }` holding the actual image or placeholder, and `.clipShape` moved to the outer square. Status
badges were re-attached as `.overlay(alignment:...)` directly on `photoSquare` rather than the old
`ZStack`-wrapping-`photo` pattern — functionally identical, just restructured around the new square. The
`ui-designer` agent explicitly recommended against capping the whole card with a fixed `.frame(height:)`,
since that breaks under Dynamic Type/localization — making each sub-element's size deterministic (square
photo, reserved bar slot, reserved 2-line title) was preferred so card height stays a pure function of
column width + text size, uniform by construction for any number of future watches. Pure layout change, no
model/business logic touched, so no new tests; both platforms build clean.
Two small same-day follow-ups to the card: **the Brand/Model order was swapped back** — Brand is `.headline`
(1 line) on top, Model is `.subheadline`/secondary below, keeping the `.lineLimit(2, reservesSpace: true)`
reservation on whichever line holds the model text (now the second line) rather than tied to font size,
since model names are the ones actually likely to wrap. **`PowerReserveBarView`'s fill got a minimum
width** (`max(geometry.size.width * fraction, 3)`) — at `fraction == 0` the filled `Capsule` was previously
0pt wide, so "depleted" (which `tint` already correctly resolves to `.red`) was invisible against the gray
track; now there's always a visible 3pt sliver.
**A Settings toggle was added to control the bar's visibility entirely**: `isPowerReserveBarEnabled`
(`@AppStorage`, literal string key shared between `SettingsView` and `WatchCardView`, same pattern as
`colorSchemePreference`/`accentColorOption` — no dedicated manager type to centralize the key on, unlike
the reminder/backup keys). Added as a `Toggle` in Settings' Appearance section (default on), with a footer
note shown only when locked, since the toggle has no visible effect until the user unlocks the underlying
feature. `WatchCardView.showsPowerReserveBar` now checks `isUnlocked && isPowerReserveBarEnabled &&
watch.powerReserveRemainingFraction != nil` — turning the toggle off falls back to the same red
`gauge.with.needle` depleted badge free/locked users already see (no new fallback UI needed, the existing
`!showsPowerReserveBar` branch already covers it), and the reserved 4pt bar-slot row from the uniformity fix
above is now also conditioned on `isPowerReserveBarEnabled` so the whole row disappears — not just goes
empty — when the feature is switched off, keeping the toggle's "off" state a clean full removal rather than
dead reserved space. Pure UI/preference change, no new tests; both platforms build clean.
A copy-only pass followed the same day, adding `Section` footers/captions wherever the user felt a
setting or field wasn't self-explanatory: `SettingsView`'s Appearance section now always explains what the
Power Reserve toggle does (previously only had a conditional locked-state note); the Purchase section
gained a footer summarizing what the one-time unlock actually includes (Insights, both reminder types,
Scheduled Backup) versus what's already free, since it previously had no footer at all. `AddWatchView`
gained footers on three previously-undocumented sections: Details (clarifies Reference Number vs. Serial
Number aren't the same thing — model identity vs. this specific unit), Specifications (notes everything's
optional, defines Caliber), and Condition & Documentation (defines Box & Papers, distinguishes Insured
Value from Purchase Price above it). Movement's existing conditional footer gained an unconditional
explanatory line on top — what Power Reserve/Wind Reminder mean when manual/automatic is selected, or why
there's nothing to fill in for quartz (battery-powered, log a replacement as a normal service record
instead). `WatchDetailView`'s Maintenance section gained a footer distinguishing it from Service History
below it. `WishlistView`'s permanently-disabled "Price Alert" toggle (a V2/subscription feature stubbed in
now, per the monetization plan) previously had zero explanation for why it can't be turned on — gained a
small "Coming in a future update" caption underneath. Pure copy change, no logic touched anywhere, so no
new tests; both platforms build clean.
A real bug the earlier brainstorm session had flagged but not yet fixed came back as a direct user report:
**custom service centers still couldn't be deleted.** Root cause confirmed: swipe-to-delete
(`.onDelete(perform: deleteCustomCenters)`) was wired at the `List` level, but `CustomCenterRow`'s
`.contextMenu` only had "Edit" — no "Delete" — and swipe gestures are unreliable/absent on macOS
specifically, which is this project's primary dev/test platform. Fixed in `ServiceCentersView.swift`:
`CustomCenterRow` gained an `onDelete: () -> Void` closure param, a destructive "Delete" context-menu item,
and a `confirmationDialog` (same pattern `WatchDetailView`'s watch-delete flow already uses) so a
misclick can't silently destroy a center; the parent view wires it to a new `deleteCustomCenter(_:)` that
just calls `modelContext.delete`. The original `.onDelete`/swipe path was left in place too — belt-and-
suspenders, matching this app's established multi-entry-point delete pattern (e.g. `WatchDetailView` also
has both a toolbar Delete and used to have a duplicate `VaultGridView` context-menu one before that was
removed as redundant in Phase 14). Pure UI fix, no model logic, no new tests; both platforms build clean.
**That context-menu-only fix turned out to still not be discoverable enough** — the user reported the same
day, after the fix above, that they still couldn't find a delete option. A first follow-up added an
always-visible red trash `Button` directly on `CustomCenterRow` — but the user then explicitly said they
didn't want a permanently-visible delete control on the row at all, and asked for it inside the edit sheet
instead, closer to how `EditOfficialContactView`'s "Reset to Default" already works. **Final design**:
the row-level button and its context-menu Delete item were both reverted (`CustomCenterRow` is back to
just "Edit" via tap or context menu); `AddServiceCenterView` (the same sheet used for both add and edit,
keyed on `centerToEdit`) gained a destructive "Delete Service Center" button in its own `Section`, shown
only when `centerToEdit != nil` — i.e. only in edit mode, never when creating a new one — with a
`confirmationDialog` before it actually deletes and dismisses. The original List-level
`.onDelete`/swipe-to-delete was left alone throughout all of this (pre-existing, never the reported
problem). **Unverified as of 2026-07-17** — same longstanding sandbox limitation as the rest of this app's
UI work; the user should confirm this final placement actually solves it before treating it as resolved.
Both platforms build clean.
After all the delete/edit churn above, the user asked for a full symmetry/consistency audit across every
CRUD-capable view — a plain-text review, no code read or written for it. Findings: Section headers, empty
states, toolbar Add buttons, and create-sheet form styling were already consistent everywhere; but three
real asymmetries surfaced — (1) three different behaviors for tapping a list row (Vault/Maintenance push to
a read-only detail view before editing; Service Centers open straight into an edit sheet with no detail
view; Wishlist did nothing at all), (2) `WishlistItem` had zero edit capability (add + swipe-delete only,
unlike every other model), (3) unlike every other real delete in the app (Watch, Service Center), Settings'
"Remove Stored Passphrase" fired immediately with no confirmation despite being `role: .destructive`. (A
fourth item, sub-collections inside the Workbench being add-only with inconsistent delete support, was
noted but not actioned — a bigger design call left for later.) The user asked to fix (2) and (3) first.
**(2) `WishlistItem` gained full edit capability**, matching the pattern just established for Service
Centers: `WishlistRow` gained an `onEdit` closure, tap-to-edit, and an "Edit" context-menu item;
`AddWishlistItemView` gained an `itemToEdit: WishlistItem?` init param (mirroring `AddServiceCenterView`'s
`centerToEdit`), branches its `save()` between mutate-existing and insert-new, and gained a "Delete
Wishlist Item" section (edit mode only) with a `confirmationDialog` — same shape as the Service Center
delete flow, right down to leaving the List-level swipe-to-delete in place alongside it.
**(3) Settings' "Remove Stored Passphrase" now confirms first**: a new `isConfirmingPassphraseRemoval`
`@State` plus a `confirmationDialog` (added inside the existing `withPassphraseAndStatusAlerts` helper,
not stacked directly onto `body`'s already-fragile modifier chain — see the type-checker note earlier in
this file) gates the actual `KeychainHelper.deletePassphrase()` call, with a message clarifying Scheduled
Backup won't run again until a new passphrase is set. Pure UI change, no model logic touched, no new tests;
both platforms build clean.
The user then asked to tackle #1 and #5 from the audit. **#1 turned out to already be resolved** as a side
effect of the Wishlist edit fix above — asked first before writing any code, since building unwanted detail
screens for Service Centers/Wishlist would've been wasted work: confirmed the two-tier system (Watch pushes
to a detail view since it's a hub with real sub-content; Service Center/Wishlist Item open their edit sheet
directly since there's nothing beyond the row's own fields to show) is the desired end state, not a gap.
**#5 — the Workbench's sub-collections gained consistent delete support, and Straps gained full edit
support.** Service Records, Wear Log, and Wind Log entries (previously add-only, with literally no way to
correct a mistaken log) all gained `.onDelete` swipe-to-delete, matching Provenance Docs' already-established
pattern — bringing all four "log entry" sub-collections to the same add+swipe-delete shape. Each delete
function also reschedules the relevant reminder afterward (Service Records → `scheduleServiceDueReminder`,
Wear Log and Wind Log → `scheduleWindReminder`), since removing a log entry can shift `serviceDueDate`/
`powerReserveExpiresAt` the same way logging one does — same reasoning `AddServiceRecordView.save()`/
`logWindNow()`/`logWearToday()` already established for scheduling after a *positive* change, just applied
to the reverse case. **Straps**, being a fundamentally different kind of sub-collection (a reusable object
with several fields worth correcting, not a one-shot timestamped event), got the full edit-sheet treatment
instead — the same pattern now shared by Service Center/Wishlist Item: `AddStrapView` gained a
`strapToEdit: Strap?` init param, branches `save()` between mutate-existing and insert-new-then-attach, and
gained a "Delete Strap" section (edit mode only) with a `confirmationDialog` — this deletes the `Strap`
object entirely, not just detaches it from the current watch (the dialog's message says so explicitly, to
avoid ambiguity with the existing "Detach" button, which only clears `watch.attachedStrap` without deleting
anything). `strapsSection` gained an "Edit Strap…" button next to "Detach" when a strap is attached, and
`WatchDetailView` gained a new `editingStrap: Strap?` `@State` + `.sheet(item:)`, mirroring exactly how
`editingCustomCenter`/`editingItem` already work in `ServiceCentersView`/`WishlistView`. Confirmed safe to
delete a `Strap` directly: `Strap.attachedWatch` has no explicit `deleteRule`, which SwiftData defaults to
`.nullify`, so `watch.attachedStrap` clears itself automatically if the deleted strap was attached — no
manual detach-before-delete step needed. Pure UI/CRUD-wiring change, no new business logic (the delete
functions mirror the shape of already-untested UI glue like `logWearToday()`), so no new tests; both
platforms build clean.
A new feature was brainstormed and built the same day: **a free Notifications panel**, a live-computed
digest of watches currently needing attention, reached via a bell button (with a red numeric badge) on the
sidebar's own toolbar in `ContentView.swift` — placed there rather than inside any one section's toolbar
so it's reachable regardless of which detail view is showing, and presented as a `.popover` with its own
internal `NavigationStack` (avoids any cross-view navigation-state coordination with whichever section
happens to be selected). Three scope decisions were made explicitly with the user before writing any code:
(1) live-computed from existing signals, not a persisted notification history — no new data model, no
`UNUserNotificationCenterDelegate` hook, can't drift from reality; (2) toolbar bell + badge over a new
sidebar section, since Insights/Maintenance already surface adjacent information and a third destination
would be redundant; (3) **free**, not gated behind the lifetime unlock. That third point got its own
explicit gating-safety discussion before building, since it's easy to accidentally cannibalize a paid
feature this way — the reasoning that made it safe: the panel only surfaces facts already free elsewhere
(the Vault card badges, `MaintenanceView`'s grouping) so it adds zero new *information*, and critically it's
**pull, not push** (only visible if the user opens the app and taps the bell) and only reflects **already-
true facts, never predictions** ("already depleted," not "will deplete in 3 hours") — both of which are
exactly the paid Reminders feature's actual differentiators (proactive delivery without opening the app,
lead-time warnings before a problem occurs). That boundary is written down explicitly in code comments (on
`Watch`'s new predicates and `NotificationsPanelView`'s header) as a guardrail: if this panel is ever
extended to show upcoming/predicted items, that would cross into replicating the paid feature and the
gating decision should be revisited.
Three new `Watch` computed properties back the digest, defined once so the panel's list and the toolbar
badge count can never disagree: `hasOpenPowerReserveNotification` (mirrors `isPowerReserveDepleted`),
`hasOpenServiceNotification` (`isServiceDue && !isOutForMaintenance`, the same filter `MaintenanceView`
already uses for its "Service Due" bucket), and `hasOpenPickupNotification` (out for maintenance with an
expected pickup date that's already passed — watches with no expected date set never trigger this, since
there's nothing to compare against). `openNotificationCount` sums all three (0–2 in practice, since
service-due and pickup-ready are mutually exclusive but power-reserve-depleted can co-occur with either) —
7 new tests in `WatchModelTests.swift` cover all four properties individually and the multi-issue-at-once
sum case. `NotificationsPanelView.swift` is a new file: two `Section`s (Power Reserve, Maintenance — the
latter combining both service-due and ready-for-pickup rows rather than two separately-headered sections
for the same word), each row a `NavigationLink(value: watch)` into `WatchDetailView` via the same
`.navigationDestination(for: Watch.self)` pattern `VaultGridView`/`MaintenanceView`/`LearnHubView` already
use, with a positive "All Caught Up" / `checkmark.circle` empty state matching `DepletedWatchesChartView`'s
precedent for "empty is the good outcome" framing. `bell`/`bell.fill`/`bell.badge.fill`/`bell.badge` were
all verified to exist via the established `NSImage`-check practice before use. No new stored `Watch` fields
(everything is computed from data that already exists), so `DataBackupManager` needed no changes this time.
Both platforms build clean and the full unit test suite passes.
**Same-day follow-up**: the user asked for the badge count to clear once acknowledged, without removing
anything from the panel's own list. New `NotificationsAcknowledgment.swift` (a static-only enum, no view,
matching `NotificationManager`/`ScheduledBackupManager`'s pattern) tracks which specific open issues have
been *seen* via a snapshot stored in `UserDefaults.standard` — `acknowledgeAll(_:)` **replaces** the stored
set with the current set of `Watch.openNotificationKeys` (a new per-issue stable string, one per open
predicate — `"\(persistentModelID)-power"` etc. — distinct from `openNotificationCount`, which is just the
total). Replacing rather than unioning is what makes a resolved-then-reopened issue correctly count as new
again automatically: its key simply won't be in the next snapshot once resolved, no separate pruning/expiry
step needed. `unacknowledgedCount(for:)` is the set difference between currently-open keys and the stored
snapshot. Acknowledgment fires automatically on `.onDisappear` when the Notifications popover closes —
matching how the OS's own notification center clears its badge once you've viewed the list, no separate
"mark as read" action needed. `ContentView`'s bell badge was renamed `unacknowledgedNotificationCount` and
now reads through this instead of the raw per-watch total.
**A real, non-flaky bug surfaced while writing `NotificationsAcknowledgmentTests`**: the one test comparing
two *different* watches' keys failed consistently (not intermittently) even after adding `@Suite(.serialized)`
to rule out cross-suite `UserDefaults` races. Root-caused via a throwaway `swift` script (see the diagnosis
in `NotificationsAcknowledgmentTests`'s and `Watch.openNotificationKeys`'s doc comments): `PersistentIdentifier`'s
`==`/`Hashable` conformance is correct even before a model is saved, but its `String(describing:)`
representation collapses to the same generic placeholder string for *every* unsaved model — only after an
actual save does the description include a genuinely unique per-row identifier. Fixed the test by inserting
*and saving* watches into a real in-memory `ModelContext` before comparing them (a single-watch test never
hit this, which is why 3 of the 4 tests already passed). This is a real, if narrow and self-correcting,
limitation of `openNotificationKeys` in the shipped app too — documented directly on that property rather
than engineered around, since it only matters for two brand-new watches created in the same instant with
the same issue type, before the next autosave. `@Suite(.serialized)` was kept on the test suite regardless,
since it's still legitimate insurance against racing `WatchModelTests`' own `UserDefaults`-touching tests.
Both platforms build clean and the full unit test suite passes (confirmed stable across repeated runs, not
just once, given the flakiness this specific bug could have masqueraded as).
Treat the monetization plan doc as the
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
xcodebuild -project "Horology Vault.xcodeproj" -scheme "Horology Vault" -destination 'platform=iOS Simulator,name=iPhone 17' build
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
  the plan are intentionally not added yet — they stay hidden until the subscription ships. **Section
  headers** (added 2026-07-15) use a shared `SectionHeader.swift` component — a `Text` with `.textCase(nil)`
  (opting out of the platform's automatic uppercasing), `.title2.weight(.semibold)`, and
  `.frame(maxWidth: .infinity, alignment: .center)` — used as the `header:` for every `Form`/`List` Section
  and the `label:` for every `DisclosureGroup` app-wide, in place of a bare `Text`; use it for any new
  Section/DisclosureGroup rather than reintroducing the platform default. One cosmetic exception:
  `ServiceCentersView`'s two `DisclosureGroup` labels center within the space left of the trailing
  disclosure chevron, not the full row width, since centering the label past the built-in chevron would
  require replacing it. **Toolbars on iOS 26 Liquid Glass** merge adjacent same-placement `ToolbarItem`s
  into one shared glass capsule by default — `VaultGridView`'s sort control and Add button were fusing into
  a single pill until a `ToolbarSpacer(.fixed, placement: .primaryAction)` was added between them (2026-07-15).
  The sort control itself is a `Menu` wrapping a `Picker`, given an icon-only `Label("Sort", systemImage:
  "arrow.up.arrow.down")`, rather than a bare menu-style `Picker` — a menu-style `Picker` renders the
  *selected option's text* (e.g. "Brand") as its own toolbar button title, which is what made it render wide
  in the first place; wrap any similarly compact toolbar picker in a `Menu` with an icon label instead of
  relying on `.pickerStyle(.menu)` alone. **Sidebar icon tinting** (2026-07-17): `ContentView`'s sidebar
  `Label`s use the `Label(title:icon:)` init so only the icon (not the row text) picks up
  `.foregroundStyle(accentColorOption.color)`, matching the Apple Reminders/Notes look — tinting the whole
  sidebar `List` background was tried first and reverted per feedback, so don't reintroduce that. **Appearance
  switching (Light/Dark/System) has a known, still-unverified fix as of 2026-07-17** — see the "Known issue"
  bullet near the end of this list before touching `ContentView`'s `.preferredColorScheme`/`.id(...)` setup.
- **View hierarchy so far:** sidebar → `VaultGridView` (grid of watches with brand/date/case-size sorting,
  empty state via `ContentUnavailableView`, `+` toolbar button sheets `AddWatchView`; long-press context
  menu has "Log Today" and, for manual/automatic watches, "Wind Watch" — **Delete was removed from this menu
  2026-07-17** since it duplicated `WatchDetailView`'s toolbar Delete, which already has its own
  `confirmationDialog`; don't re-add a second delete entry point here) → `WatchCardView` (photo thumbnail,
  smart-cropped via Vision saliency detection so the square crop centers on the subject rather than the
  geometric center — see `WatchCardView.swift`'s `saliencyFocusPoint`/`SmartCroppedImage` — plus an orange
  service-due wrench badge (superseded by a blue `shippingbox.fill` badge while the watch is out for
  maintenance, added 2026-07-17) and, since 2026-07-17, a red "gauge.with.needle" power-reserve-depleted
  badge in the opposite corner) → `WatchDetailView` ("the Workbench": Form with an Edit toolbar button
  reopening `AddWatchView` pre-filled, a destructive Delete toolbar button, and these sections: Overview
  incl. optional reference number, Specifications and Condition & Documentation (collector/insurance detail
  fields, hidden entirely when empty — see the field-addition paragraph earlier in this file), Reminders
  (per-watch Service Due/Wind Reminder toggles + a Service Interval override, added 2026-07-17 right after
  Overview for visibility — see the reminder-gating paragraphs earlier in this file), Straps (attach/detach
  picker + "Add New Strap…" → `AddStrapView` sheet, flags straps already attached elsewhere), Maintenance
  ("Drop Off for Maintenance…" → `DropOffForMaintenanceView` sheet, or once out, a "Mark Picked Up" button
  that clears the state and opens Log Service directly — see the out-for-maintenance paragraph earlier in
  this file), Service History (`AccuracyChartView` chart + "Log Service…" → `AddServiceRecordView` sheet),
  Wear Log ("Log Today" button + sorted `WearLog` entries), Power Reserve (manual/automatic watches only,
  see the Winding Log bullet below), Provenance ("Add Document…" → `AddProvenanceDocView` sheet using
  `.fileImporter` for PDF/image + swipe-to-delete list), and Fit Preview (embeds `FitDiagramView`)).
  `AddStrapView`/`AddServiceRecordView`/`AddProvenanceDocView`/`DropOffForMaintenanceView` are private structs
  defined inside `WatchDetailView.swift`, not separate files. Sibling sections: `FitCalculatorView`
  (standalone watch picker embedding `FitDiagramView`, a `Canvas`-based top-down lug-to-lug-vs-wrist diagram
  with a fits/overhangs verdict), `WishlistView` (list of `WishlistItem`, price-alert toggle present but
  disabled pending V2), `MaintenanceView` (watches split into Out for Maintenance / Service Due / Up to Date
  via `Watch.isOutForMaintenance`/`isServiceDue` — Out for Maintenance added 2026-07-17, excluded from the
  other two buckets so a watch never appears twice — rows push into `WatchDetailView`), `ServiceCentersView` (`.searchable` List with two
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
  user should do a final visual pass in Xcode. **Bug fixed 2026-07-17:** `LearnTopicRow`, `CategoryChip`,
  and `InYourVaultCard` were hardcoded to `Color.accentColor` (a fixed asset-catalog color that does not
  track the app's `.tint()` modifier), so Learn Hub's icons silently ignored whatever accent color the user
  picked in Settings; fixed by having each read `@AppStorage("accentColorOption")` directly instead, the
  same pattern `ContentView`/`SettingsView` already use — use `accentColorOption.color`, never
  `Color.accentColor`, anywhere in this app that needs the user's chosen accent.
- **Winding Log / Power Reserve tracking** (added 2026-07-17, Phase 14, not originally in the monetization
  plan — same "shipped outside the plan" pattern as Learn Hub): a mechanical-watch winding tracker.
  `Watch.swift` gained a `MovementType` enum (`.manual`/`.automatic`/`.quartz`, `Codable`+`CaseIterable`),
  optional `movementType`/`powerReserveHours` fields, and a cascade-delete `windLogs` relationship to the new
  `WindLog.swift` model (mirrors `WearLog`: just `dateWound` + a `watch` back-reference). Four computed
  properties on `Watch` do the actual tracking: `lastWoundDate` (max of `windLogs`), `lastPoweredDate`
  (`.manual` → `lastWoundDate` only; `.automatic` → the later of `lastWoundDate` and the most recent
  `WearLog.dateWorn`, since wearing an automatic also recharges its mainspring via wrist motion; `.quartz`/
  unset → `nil`, quartz doesn't track this at all), `powerReserveExpiresAt` (`lastPoweredDate` +
  `powerReserveHours` hours), and `isPowerReserveDepleted`. **Known, intentional scope cut:** an automatic
  watch sitting in a winder box — not worn, not explicitly logged as wound — has no signal the app can see,
  so it can read as falsely depleted; this is accepted, not a bug to fix. Quartz movements deliberately got
  no new schema at all — a battery swap is just a normal `ServiceRecord` with `serviceType` "Battery
  Replacement" (already free text), reusing existing infra instead of a parallel system. UI: `AddWatchView`
  gained a "Movement" section (type picker; the power-reserve-hours field only shows for manual/automatic
  and is cleared via `effectivePowerReserveHours` if the user switches away from those), `WatchDetailView`
  gained a "Power Reserve" section (Wind Watch button, relative-date status text via
  `.formatted(.relative(presentation: .named))`, wind history list), `VaultGridView`'s context menu gained a
  matching "Wind Watch" quick action, and `WatchCardView` gained a red "gauge.with.needle" badge for
  depleted watches (SF Symbol existence verified with a throwaway `NSImage` check before use, per the
  established practice below after the "feather" incident). `WindLog` is registered in the `Schema([...])`
  array in `Horology_Vault_App.swift`. Covered by 10 new tests in `WatchModelTests.swift` (movement-type
  branching of `lastPoweredDate`, `WindLog` cascade-delete, folded into the existing "all relationship
  kinds" cascade test). Both platforms build clean, full suite passes; not yet visually confirmed in Xcode,
  same sandbox limitation as everything else UI in this project.
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
  so hiding it would prevent it from ever doing its job of converting a browser into a buyer. **Cost-per-wear
  joined Insights as a 5th card, 2026-07-15**: `Watch` gained an optional `purchasePrice: Double?` and a
  computed `costPerWear: Double?` (`nil` unless both `purchasePrice` is set and `wearLogs` is non-empty),
  and `CostPerWearChartView.swift` (modeled on `WearFrequencyChartView.swift`) renders it inside
  `DashboardView`, inheriting the existing paywall automatically — no new gating code. The raw
  `purchasePrice` is shown for free on `WatchDetailView`'s Overview section (it's just data the user
  entered); `costPerWear` itself is deliberately not shown there, staying Insights-exclusive by design, so
  the paywall keeps meaning something. `purchasePrice` round-trips through the encrypted backup but is
  intentionally excluded from CSV export/import — see `DataBackupManager.swift`'s CSV section comment.
  **Power Reserve joined Insights as a 6th card, 2026-07-17** (see the Winding Log bullet below for the
  underlying model): `PowerReserveChartView.swift` (modeled on `ServiceStatusChartView.swift`) charts hours
  remaining/overdue until each manual/automatic watch's mainspring depletes, from `Watch.powerReserveExpiresAt`;
  quartz watches and watches without a movement/power-reserve spec are excluded. Same paywall-inheritance
  pattern as Cost per Wear — no new gating code, no new tests (pure presentation over already-tested
  computed properties).
  **Scheduled Backup joined Insights as gated, 2026-07-15** (see below) — manual export/backup remains free regardless.
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
  anything else. This feature's `BGTaskSchedulerPermittedIdentifiers`/`UIBackgroundModes` entries are merged
  into the generated iOS Info.plist via the `INFOPLIST_FILE[sdk=...]` build setting pointing at
  `Info-iOS-BackgroundTasks.plist` — that file is intentionally *not* a Copy Bundle Resources member,
  since Info.plist merging is a separate build step from resource copying. Xcode 16's synchronized-group
  project format was nonetheless auto-including it as a stray Copy Bundle Resources member (a build
  warning); fixed 2026-07-15 with a `PBXFileSystemSynchronizedBuildFileExceptionSet` in `project.pbxproj`
  excluding it from the app target's synchronized-group membership — confirmed via `plutil -lint` plus
  clean macOS and iOS Simulator builds with zero warnings. `SettingsView`'s "Scheduled Backup" section is `@ViewBuilder`-branched on the same
  `isUnlocked` pattern `purchaseStatusSection` already uses, showing a compact in-section paywall row
  instead of `DashboardView`'s full-screen treatment, since it's one `Section` in a multi-section `Form`.
- **Persistence:** SwiftData (`ModelContainer` / `@Query` / `@Model`), configured once in
  `Horology_Vault_App.swift` and injected via `.modelContainer(...)`. Current schema is
  `[Watch.self, Strap.self, ServiceRecord.self, UserProfile.self, WishlistItem.self, WearLog.self,
  ProvenanceDoc.self, WindLog.self, CustomServiceCenter.self, Entitlements.self, ServiceContactOverride.self]`
  (`WindLog` added 2026-07-17, see the Winding Log bullet above). `Watch`
  cascade-deletes its `ServiceRecord`s, `WearLog`s, `WindLog`s, and `ProvenanceDoc`s, and
  nullifies its `Strap` relationship on delete; `Watch.isServiceDue` flags watches more than 3 years past
  their last (or acquisition) date, now derived from a shared `Watch.serviceDueDate` computed property so
  `MaintenanceView` and `NotificationManager`'s reminder scheduling can never disagree on the due date.
  `NotificationManager.scheduleServiceDueReminder(for:isUnlocked:)`/`cancelServiceDueReminder(for:)`, plus
  the equivalent `scheduleWindReminder(for:isUnlocked:)`/`cancelWindReminder(for:)` pair added 2026-07-17
  (see the reminder-gating paragraph earlier in this file for the full story), are called from
  `AddWatchView.save()` (create + edit, both reminders), `AddServiceRecordView.save()` (logging a service
  resets the 3-year clock, Service Due only), `WatchDetailView`'s delete confirmation (cancels both — note
  `VaultGridView`'s own context-menu Delete was removed entirely in Phase 14, see the Winding Log bullet),
  and `WatchDetailView`'s "Wind Watch"/"Log Today" actions plus `VaultGridView`'s duplicate quick-action
  versions of both (reschedule the wind reminder only, since either can shift `powerReserveExpiresAt`).
  Every one of those call sites reads its own `Entitlements` `@Query`
  and passes `isUnlocked` through — `NotificationManager` takes gating as an explicit parameter rather than
  querying SwiftData itself. `ContentView` requests notification authorization once at launch and reschedules
  every watch's reminders via `.onChange(of: isUnlocked, initial: true)`, so both a fresh launch and a
  mid-session purchase trigger a full reschedule. Reminder identifiers are derived from
  `watch.persistentModelID` rather than a new stored field — no schema change was needed for either
  reminder feature. `DataBackupManager.swift` (also static-only, no view) provides
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
  service centers. Both `@Model`s gained optional contact fields 2026-07-15: `ServiceContactOverride` added
  `phone`/`address`/`secondaryWebsite` (the bundled `OfficialServiceContact` struct itself still
  deliberately carries only name/website/notes — phone and address are override-only, surfaced through
  `EffectiveOfficialContact`'s passthrough computed properties, never the base struct), and
  `CustomServiceCenter` (which already had `phone`/`address`) added `secondaryWebsite` to match. Plain
  additive optionals, no schema migration, same low-risk pattern as `Watch.purchasePrice`. `Watch` also has
  an optional `referenceNumber`. `Strap` has optional
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
  `Horology_Vault_App.swift`. `PurchaseManager.purchase()`'s `switch` on the `VerificationResult` now
  explicitly handles `.unverified(_, let verificationError)` (2026-07-15) by setting `lastError` — it used
  to silently do nothing for a completed-but-unverified transaction, indistinguishable from every other
  silent-no-op path in that function. Real bug, found while debugging the macOS StoreKit purchase failure
  below; keep this handling even though it wasn't the root cause that time.
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
- **Known issue (open as of 2026-07-15): macOS-native StoreKit Testing purchase failure.** Tapping "Unlock
  Full Version" in the macOS build (run from Xcode, `Configuration.storekit`) shows a normal-looking
  purchase sheet, but `product.purchase()` throws `ASDErrorDomain Code=825 "No transactions in response"`
  before the `.success`/`.userCancelled`/`.pending` switch is even reached — no entitlement is written.
  Confirmed NOT an app-code bug: product IDs match exactly, no duplicate `Entitlements` rows in the on-disk
  store (checked directly via `sqlite3`), all `Configuration.storekit` error-simulation flags are off,
  Debug → StoreKit → Manage Transactions shows nothing stuck, and `reconcileEntitlements()` correctly
  finds "not entitled" against a freshly-run reconciliation. Clearing
  `~/Library/Caches/com.apple.storekitagent/Octane/com.angelburgos.HorologyVault/` and fully restarting
  Xcode did not resolve it. Working theory: macOS StoreKit Testing runs through `storekitagent`, a
  persistent per-user system daemon (unlike iOS Simulator, which isolates StoreKit Testing per simulator
  device) — this session's heavy local-price churn (three price edits, Ask-to-Buy toggled, manual
  transaction deletion) may have left the *running* daemon process itself in a bad state that a cache
  clear can't touch. Next step: retry after a full Mac restart (force-kills/restarts the daemon); if
  `ASDErrorDomain 825` persists even then, treat iOS Simulator as the primary target for purchase-flow
  testing going forward rather than macOS-native StoreKit Testing.
- **Known issue (open/UNVERIFIED as of 2026-07-17, third fix attempt in place): appearance switching may
  still get stuck on the wrong color scheme.** Reported bug: switching Settings' Appearance preference from
  Light to System, with the Mac's own system appearance set to Dark, left some surfaces — notably the
  `NavigationSplitView` sidebar — visibly stuck in light-mode styling instead of following the system. Two
  earlier fix attempts (an explicit `NSApp.appearance` assignment via `.onChange(of: colorSchemePreference,
  initial: true)`, then a `splitView.id(colorSchemePreference)` forced-subtree-rebuild) were both in place
  together and the user retested and confirmed the bug **still happened** — ruling out both theories (window
  chrome appearance, and stale SwiftUI view identity). Root cause identified 2026-07-17: `.preferredColorScheme(nil)`
  itself is the culprit — `ColorSchemePreference.colorScheme` returns `nil` for `.system` (see
  `SettingsView.swift`), and there's a long-standing SwiftUI/AppKit bug where once a window's appearance has
  been explicitly overridden (Light or Dark), passing `nil` later does not reliably revert it to tracking
  the OS appearance; the stuck state lives on the `NSWindow`/its `NSVisualEffectView` vibrancy material
  itself, which is exactly why neither the `NSApp.appearance` fix nor the `.id()` view-identity reset could
  touch it. **Third fix (in place, not yet user-retested):** `ContentView` never passes `nil` to
  `.preferredColorScheme` on macOS anymore. A new `SystemAppearanceObserver` (`@Observable`, defined at the
  bottom of `ContentView.swift` in the `#if os(macOS)` block) tracks the real OS appearance via KVO on
  `NSApplication.effectiveAppearance` (Apple-documented as observable) and exposes it as a concrete
  `ColorScheme`. `ContentView.effectiveColorScheme` resolves `.system` to that observed value instead of
  `nil` (iOS keeps using `ColorSchemePreference.colorScheme`'s `nil` fallback unchanged, since this bug is
  macOS-specific). The now-unnecessary `splitView.id(colorSchemePreference)` forced-rebuild was removed as
  part of this fix since it no longer serves a purpose. Both macOS and iOS Simulator builds are clean and
  the full unit test suite passes — **the user has not yet retested whether this third attempt actually
  fixes the reported bug; treat it as unverified, not resolved, until confirmed.**
