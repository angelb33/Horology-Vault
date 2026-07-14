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
        case settings = "Settings"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .vault: "clock"
            case .fitCalculator: "ruler"
            case .wishlist: "star"
            case .maintenance: "wrench.and.screwdriver"
            case .settings: "gearshape"
            }
        }
    }

    @State private var selection: Section? = .vault

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
            case .settings:
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Watch.self, inMemory: true)
}
