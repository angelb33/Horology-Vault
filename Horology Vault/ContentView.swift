//
//  ContentView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/10/26.
//

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    enum Section: String, CaseIterable, Identifiable {
        case vault = "Vault"
        case learnHub = "Learn Hub"
        case insights = "Insights"
        case fitCalculator = "Fit Calculator"
        case wishlist = "Wishlist"
        case maintenance = "Maintenance"
        case serviceCenters = "Service Centers"
        case settings = "Settings"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .vault: "clock"
            case .learnHub: "book.closed"
            case .insights: "chart.bar.xaxis"
            case .fitCalculator: "ruler"
            case .wishlist: "star"
            case .maintenance: "wrench.and.screwdriver"
            case .serviceCenters: "wrench.adjustable"
            case .settings: "gearshape"
            }
        }
    }

    @State private var selection: Section? = .vault
    @State private var purchaseManager = PurchaseManager()
    @State private var isShowingNotifications = false
    @Environment(\.modelContext) private var modelContext
    @Query private var watches: [Watch]
    @Query private var entitlements: [Entitlements]

    /// Only counts issues the user hasn't already acknowledged (via closing the Notifications
    /// popover) — see `NotificationsAcknowledgment`'s doc comment. For why the underlying
    /// signals are free and don't replicate the paid Reminders feature, see
    /// `Watch.openNotificationCount`'s doc comment.
    private var unacknowledgedNotificationCount: Int {
        NotificationsAcknowledgment.unacknowledgedCount(for: watches)
    }

    @AppStorage("colorSchemePreference") private var colorSchemePreference: ColorSchemePreference = .system
    @AppStorage("accentColorOption") private var accentColorOption: AccentColorOption = .blue
    #if os(macOS)
    @State private var systemAppearanceObserver = SystemAppearanceObserver()
    #endif

    /// Never resolves to `nil` on macOS, even for `.system`. `.preferredColorScheme(nil)` has a
    /// long-standing SwiftUI/AppKit bug: once a window's appearance has been explicitly overridden
    /// (Light or Dark), passing `nil` later does not reliably revert it to tracking the OS
    /// appearance — surfaces like the NavigationSplitView sidebar's NSVisualEffectView vibrancy
    /// material can get stuck on the last explicit appearance. Neither a direct `NSApp.appearance`
    /// assignment nor an `.id()`-forced subtree rebuild (both tried previously) fixed this, because
    /// the stuck state lives on the NSWindow itself, not the SwiftUI view identity. The fix is to
    /// never pass `nil`: track the real system appearance ourselves via KVO on
    /// `NSApp.effectiveAppearance` (Apple-documented as observable) and always feed
    /// `.preferredColorScheme` a concrete value.
    private var effectiveColorScheme: ColorScheme? {
        #if os(macOS)
        switch colorSchemePreference {
        case .system: systemAppearanceObserver.colorScheme
        case .light: .light
        case .dark: .dark
        }
        #else
        colorSchemePreference.colorScheme
        #endif
    }

    /// Service Due and Wind reminders are both gated behind the lifetime unlock — see
    /// `NotificationManager`'s doc comment. Exposed here so `body` can reschedule everything
    /// the moment this flips (a mid-session purchase activates reminders immediately, no
    /// relaunch needed), not just once at launch.
    private var isUnlocked: Bool {
        entitlements.first?.isLifetimeUnlocked ?? false
    }

    var body: some View {
        splitView
            .environment(purchaseManager)
            .tint(accentColorOption.color)
            .preferredColorScheme(effectiveColorScheme)
            #if os(macOS)
            .onChange(of: colorSchemePreference, initial: true) { _, newValue in
                NSApp.appearance = newValue.nsAppearance
            }
            #endif
            .onChange(of: isUnlocked, initial: true) { _, newValue in
                NotificationManager.rescheduleAll(for: watches, isUnlocked: newValue)
            }
            .task {
                NotificationManager.requestAuthorizationIfNeeded()
                seedDemoDataIfNeeded()
                purchaseManager.configure(modelContext: modelContext)
                await purchaseManager.loadProduct()
                await purchaseManager.reconcileEntitlementsOnLaunch()
                #if os(macOS)
                ScheduledBackupManager.startBackgroundActivityScheduler(context: modelContext)
                #endif
                _ = ScheduledBackupManager.performBackupIfDue(context: modelContext)
            }
    }

    /// Split out from `body` purely to keep `body` readable; unlike an earlier version of this
    /// code, this subtree no longer needs a forced `.id(colorSchemePreference)` rebuild — that
    /// was working around a stuck-appearance bug that's now fixed at the source by
    /// `effectiveColorScheme` never passing `nil` to `.preferredColorScheme` on macOS.
    private var splitView: some View {
        NavigationSplitView {
            List {
                ForEach(Section.allCases) { section in
                    Button {
                        selection = section
                    } label: {
                        Label {
                            Text(section.rawValue)
                        } icon: {
                            Image(systemName: section.systemImage)
                                .foregroundStyle(accentColorOption.color)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(section == selection ? accentColorOption.color.opacity(0.25) : Color.clear)
                            .padding(.horizontal, 6)
                    )
                    .listRowBackground(Color.clear)
                }
            }
            #if os(macOS)
            .focusable()
            .onMoveCommand(perform: moveSidebarSelection)
            #endif
            .navigationTitle("Horology Vault")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    notificationsBellButton
                }
            }
        } detail: {
            switch selection {
            case .vault, nil:
                VaultGridView()
            case .learnHub:
                LearnHubView()
            case .insights:
                DashboardView()
            case .fitCalculator:
                FitCalculatorView()
            case .wishlist:
                WishlistView()
            case .maintenance:
                MaintenanceView()
            case .serviceCenters:
                ServiceCentersView()
            case .settings:
                SettingsView()
            }
        }
    }

    /// Drives arrow-key navigation through the sidebar. The sidebar rows are plain `Button`s
    /// rather than a native `List(selection:)` (see `splitView`'s custom inset `.background`) so
    /// the selection highlight can use the user's chosen accent color — `.sidebar`-style
    /// `List(selection:)` always paints its native highlight with the system accent-color
    /// preference, which no public SwiftUI tint modifier can override. Losing the native
    /// selection wiring also loses its built-in arrow-key handling, so this replaces it manually.
    /// `onMoveCommand`/`MoveCommandDirection` are macOS/tvOS-only APIs, hence the `#if os(macOS)`
    /// both here and at the `splitView` call site.
    #if os(macOS)
    private func moveSidebarSelection(_ direction: MoveCommandDirection) {
        let cases = Section.allCases
        guard let current = selection, let index = cases.firstIndex(of: current) else {
            selection = cases.first
            return
        }
        switch direction {
        case .up:
            selection = cases[max(cases.startIndex, index - 1)]
        case .down:
            selection = cases[min(cases.index(before: cases.endIndex), index + 1)]
        default:
            break
        }
    }
    #endif

    /// Lives on the sidebar's own toolbar (not any individual section's) so it's reachable
    /// regardless of which detail view is showing — matches the OS notification-center pattern
    /// of being anchored to a persistent chrome element rather than tucked into one screen.
    private var notificationsBellButton: some View {
        Button {
            isShowingNotifications = true
        } label: {
            Image(systemName: unacknowledgedNotificationCount > 0 ? "bell.badge.fill" : "bell")
        }
        .overlay(alignment: .topTrailing) {
            if unacknowledgedNotificationCount > 0 {
                Text("\(unacknowledgedNotificationCount)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(.red, in: Circle())
                    .offset(x: 10, y: -8)
            }
        }
        .accessibilityLabel(unacknowledgedNotificationCount > 0 ? "Notifications, \(unacknowledgedNotificationCount) new" : "Notifications")
        .popover(isPresented: $isShowingNotifications) {
            NotificationsPanelView()
        }
    }

    /// First-launch-only: gives a brand-new install something to look at in the read-only demo
    /// state (see the monetization plan's Section 8 gating decision) instead of an empty Vault.
    /// Gated on both `entitlements` and `watches` being empty so this never fires for an existing
    /// user's real collection — only a truly fresh store gets the sample watch.
    private func seedDemoDataIfNeeded() {
        guard entitlements.isEmpty, watches.isEmpty else { return }
        modelContext.insert(Watch(
            brand: "Sample Brand",
            model: "Example Watch",
            referenceNumber: "SAMPLE-001",
            caseDiameterMM: 40,
            lugToLugMM: 47,
            lugWidthMM: 20,
            movementType: .automatic,
            powerReserveHours: 42
        ))
        modelContext.insert(Entitlements())
    }
}

#if os(macOS)
private extension ColorSchemePreference {
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

/// Tracks the OS-level Light/Dark appearance via KVO on `NSApplication.effectiveAppearance`
/// (documented by Apple as observable), so `ContentView` always has a concrete `ColorScheme` to
/// hand `.preferredColorScheme` — see `ContentView.effectiveColorScheme` for why `nil` is never
/// used on macOS.
@Observable
final class SystemAppearanceObserver {
    private(set) var colorScheme: ColorScheme
    private var observation: NSKeyValueObservation?

    init() {
        colorScheme = Self.resolve(NSApp.effectiveAppearance)
        observation = NSApp.observe(\.effectiveAppearance) { [weak self] app, _ in
            let resolved = Self.resolve(app.effectiveAppearance)
            DispatchQueue.main.async {
                self?.colorScheme = resolved
            }
        }
    }

    private static func resolve(_ appearance: NSAppearance) -> ColorScheme {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
    }
}
#endif

#Preview {
    ContentView()
        .modelContainer(for: Watch.self, inMemory: true)
}
