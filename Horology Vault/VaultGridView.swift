//
//  VaultGridView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/10/26.
//

import SwiftUI
import SwiftData

struct VaultGridView: View {
    enum SortOption: String, CaseIterable, Identifiable {
        case brand = "Brand"
        case acquisitionDate = "Acquisition Date"
        case caseSize = "Case Size"

        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext

    @Query private var watches: [Watch]
    @Query private var entitlements: [Entitlements]
    @State private var sortOption: SortOption = .brand
    @State private var isAddingWatch = false
    @State private var searchText = ""

    private var isUnlocked: Bool {
        entitlements.first?.isLifetimeUnlocked ?? false
    }

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 16)]

    private var sortedWatches: [Watch] {
        switch sortOption {
        case .brand:
            watches.sorted { $0.brand < $1.brand }
        case .acquisitionDate:
            watches.sorted { $0.acquisitionDate > $1.acquisitionDate }
        case .caseSize:
            watches.sorted { $0.caseDiameterMM < $1.caseDiameterMM }
        }
    }

    private var filteredWatches: [Watch] {
        guard !searchText.isEmpty else { return sortedWatches }
        return sortedWatches.filter {
            $0.brand.localizedCaseInsensitiveContains(searchText)
                || $0.model.localizedCaseInsensitiveContains(searchText)
                || ($0.referenceNumber?.localizedCaseInsensitiveContains(searchText) ?? false)
                || ($0.serialNumber?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if watches.isEmpty {
                    ContentUnavailableView(
                        "No Watches Yet",
                        systemImage: "clock",
                        description: Text("Add a watch to start building your Vault.")
                    )
                } else if filteredWatches.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(filteredWatches) { watch in
                                NavigationLink(value: watch) {
                                    WatchCardView(watch: watch)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Log Today", systemImage: "checkmark.circle") {
                                        logWearToday(for: watch)
                                    }
                                    if watch.movementType == .manual || watch.movementType == .automatic {
                                        Button("Wind Watch", systemImage: "arrow.clockwise.circle") {
                                            logWindNow(for: watch)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Vault")
            .searchable(text: $searchText, prompt: "Search by brand, model, or reference")
            .navigationDestination(for: Watch.self) { watch in
                WatchDetailView(watch: watch)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    // A plain menu-style Picker shows the *selected option's text*
                    // ("Brand", "Acquisition Date", ...) as its toolbar button title,
                    // which is what made this control render as a wide pill. Wrapping
                    // the Picker in a Menu with an icon-only label keeps the same
                    // tap-to-choose behavior (SwiftUI still checkmarks the selected
                    // option) while giving the toolbar button a small, fixed icon
                    // size that matches the Add button instead of growing with the
                    // selected option's label length.
                    Menu {
                        Picker("Sort", selection: $sortOption) {
                            ForEach(SortOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }
                // Without an explicit spacer, iOS 26's Liquid Glass toolbar fuses
                // adjacent primaryAction items into one shared glass capsule, so the
                // Sort menu and the Add button read as a single merged pill. A
                // ToolbarSpacer breaks the shared background so each control gets its
                // own capsule and reads as a distinct, separately-tappable action.
                ToolbarSpacer(.fixed, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingWatch = true
                    } label: {
                        Label("Add Watch", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingWatch) {
                AddWatchView()
            }
        }
    }

    /// Quicker access to Wear Log's "Log Today" action (normally reached via `WatchDetailView`'s
    /// Wear Log section) directly from the Vault grid's context menu, same insert as `logWearToday()`
    /// there.
    private func logWearToday(for watch: Watch) {
        let entry = WearLog(watch: watch)
        modelContext.insert(entry)
        // Wearing an automatic also recharges its mainspring (see Watch.lastPoweredDate), so
        // this can push powerReserveExpiresAt out; a no-op reschedule for manual/quartz watches.
        NotificationManager.scheduleWindReminder(for: watch, isUnlocked: isUnlocked)
        NotificationManager.schedulePowerReserveDepletedReminder(for: watch, isUnlocked: isUnlocked)
    }

    /// Quicker access to Power Reserve's "Wind Watch" action (normally reached via
    /// `WatchDetailView`'s Power Reserve section) directly from the Vault grid's context menu,
    /// same insert as `logWindNow()` there.
    private func logWindNow(for watch: Watch) {
        let entry = WindLog(watch: watch)
        modelContext.insert(entry)
        NotificationManager.scheduleWindReminder(for: watch, isUnlocked: isUnlocked)
        NotificationManager.schedulePowerReserveDepletedReminder(for: watch, isUnlocked: isUnlocked)
    }

}

#Preview {
    VaultGridView()
        .modelContainer(for: [Watch.self, Entitlements.self], inMemory: true)
}
