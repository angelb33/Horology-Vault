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
    @Environment(PurchaseManager.self) private var purchaseManager

    @Query private var watches: [Watch]
    @Query private var entitlements: [Entitlements]
    @State private var sortOption: SortOption = .brand
    @State private var isAddingWatch = false
    @State private var watchPendingDeletion: Watch?

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
                        if !isUnlocked {
                            unlockBanner
                        }
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(sortedWatches) { watch in
                                NavigationLink(value: watch) {
                                    WatchCardView(watch: watch)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        watchPendingDeletion = watch
                                    }
                                }
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
                    .disabled(!isUnlocked)
                }
            }
            .sheet(isPresented: $isAddingWatch) {
                AddWatchView()
            }
            .confirmationDialog(
                "Delete \(watchPendingDeletion?.brand ?? "") \(watchPendingDeletion?.model ?? "")?",
                isPresented: Binding(
                    get: { watchPendingDeletion != nil },
                    set: { isPresented in if !isPresented { watchPendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let watch = watchPendingDeletion {
                        NotificationManager.cancelServiceDueReminder(for: watch)
                        modelContext.delete(watch)
                    }
                    watchPendingDeletion = nil
                }
            }
        }
    }

    /// Persistent unlock prompt for the read-only demo state — per the monetization plan's
    /// gating decision, this replaces a hard paywall so a browser can see the Vault (and this
    /// one sample watch) before paying.
    private var unlockBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Unlock Full Version", systemImage: "lock.open")
                .font(.headline)
            Text("Add unlimited watches, straps, and service history with a one-time purchase.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Unlock Full Version") {
                Task { await purchaseManager.purchase() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top)
    }
}

#Preview {
    VaultGridView()
        .modelContainer(for: Watch.self, inMemory: true)
        .environment(PurchaseManager())
}
