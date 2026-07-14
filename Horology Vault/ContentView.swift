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
        case fitCalculator = "Fit Calculator"
        case wishlist = "Wishlist"
        case maintenance = "Maintenance"
        case serviceCenters = "Service Centers"
        case settings = "Settings"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .vault: "clock"
            case .fitCalculator: "ruler"
            case .wishlist: "star"
            case .maintenance: "wrench.and.screwdriver"
            case .serviceCenters: "wrench.adjustable"
            case .settings: "gearshape"
            }
        }
    }

    @State private var selection: Section? = .vault
    @Query private var watches: [Watch]

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
        .task {
            NotificationManager.requestAuthorizationIfNeeded()
            NotificationManager.rescheduleAll(for: watches)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Watch.self, inMemory: true)
}
