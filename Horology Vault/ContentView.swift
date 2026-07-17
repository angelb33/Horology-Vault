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
    @Environment(\.modelContext) private var modelContext
    @Query private var watches: [Watch]
    @Query private var entitlements: [Entitlements]

    @AppStorage("colorSchemePreference") private var colorSchemePreference: ColorSchemePreference = .system
    @AppStorage("accentColorOption") private var accentColorOption: AccentColorOption = .blue

    var body: some View {
        splitView
            .environment(purchaseManager)
            .tint(accentColorOption.color)
            .preferredColorScheme(colorSchemePreference.colorScheme)
            #if os(macOS)
            // `.preferredColorScheme(nil)` alone doesn't reliably force AppKit to re-cascade the
            // effective appearance to already-materialized NSVisualEffectView-backed surfaces
            // (e.g. the NavigationSplitView sidebar's vibrancy material) when switching back to
            // "System" after a concrete Light/Dark choice — they can get stuck on the last
            // explicit appearance even after NSApp.appearance is updated. `splitView.id(...)`
            // below forces those surfaces to be fully torn down and recreated, which is what
            // actually fixes the stale-appearance sidebar; this NSApp.appearance assignment
            // covers window chrome outside that subtree. `initial: true` applies it at launch too.
            .onChange(of: colorSchemePreference, initial: true) { _, newValue in
                NSApp.appearance = newValue.nsAppearance
            }
            #endif
            .task {
                NotificationManager.requestAuthorizationIfNeeded()
                NotificationManager.rescheduleAll(for: watches)
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

    /// Split out from `body` so `.id(colorSchemePreference)` can force this whole subtree —
    /// sidebar and detail pane alike — to be fully torn down and rebuilt whenever the preference
    /// changes, without also restarting `body`'s `.task` (which would needlessly redo one-time
    /// launch work like notification scheduling and StoreKit reconciliation).
    private var splitView: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { section in
                Label {
                    Text(section.rawValue)
                } icon: {
                    Image(systemName: section.systemImage)
                        .foregroundStyle(accentColorOption.color)
                }
                .tag(section)
            }
            .navigationTitle("Horology Vault")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            #endif
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
        .id(colorSchemePreference)
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
#endif

#Preview {
    ContentView()
        .modelContainer(for: Watch.self, inMemory: true)
}
