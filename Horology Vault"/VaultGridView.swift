//
//  VaultGridView.swift
//  Horology Vault"
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

    @Query private var watches: [Watch]
    @State private var sortOption: SortOption = .brand
    @State private var isAddingWatch = false

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

    var body: some View {
        NavigationStack {
            Group {
                if watches.isEmpty {
                    ContentUnavailableView(
                        "No Watches Yet",
                        systemImage: "clock",
                        description: Text("Add a watch to start building your Vault.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(sortedWatches) { watch in
                                NavigationLink(value: watch) {
                                    WatchCardView(watch: watch)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Vault")
            .navigationDestination(for: Watch.self) { watch in
                WatchDetailView(watch: watch)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Picker("Sort", selection: $sortOption) {
                        ForEach(SortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }
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
}

#Preview {
    VaultGridView()
        .modelContainer(for: Watch.self, inMemory: true)
}
