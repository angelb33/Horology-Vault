//
//  ContentView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/10/26.
//

import SwiftUI
import SwiftData

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
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.systemImage)
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
        .environment(purchaseManager)
        .tint(accentColorOption.color)
        .preferredColorScheme(colorSchemePreference.colorScheme)
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

    /// First-launch-only: gives a brand-new install something to look at in the read-only demo
    /// state (see the monetization plan's Section 8 gating decision) instead of an empty Vault.
    /// Gated on both `entitlements` and `watches` being empty so this never fires for an existing
    /// user's real collection — only a truly fresh store gets the sample watch.
    private func seedDemoDataIfNeeded() {
        guard entitlements.isEmpty, watches.isEmpty else { return }
        modelContext.insert(Watch(
            brand: "Rolex",
            model: "Explorer",
            referenceNumber: "224270",
            caseDiameterMM: 36,
            lugToLugMM: 44,
            lugWidthMM: 20
        ))
        modelContext.insert(Entitlements())
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Watch.self, inMemory: true)
}
