//
//  MaintenanceView.swift
//  Horology Vault"
//
//  Created by Angel Burgos on 7/11/26.
//

import SwiftUI
import SwiftData

struct MaintenanceView: View {
    @Query private var watches: [Watch]

    /// Watches past their service interval, most overdue first (oldest service /
    /// acquisition date at the top so the row that needs attention leads the list).
    private var dueWatches: [Watch] {
        watches
            .filter(\.isServiceDue)
            .sorted { referenceDate(for: $0) < referenceDate(for: $1) }
    }

    private var upToDateWatches: [Watch] {
        watches
            .filter { !$0.isServiceDue }
            .sorted { referenceDate(for: $0) < referenceDate(for: $1) }
    }

    private func referenceDate(for watch: Watch) -> Date {
        watch.lastServiceDate ?? watch.acquisitionDate
    }

    var body: some View {
        NavigationStack {
            Group {
                if watches.isEmpty {
                    ContentUnavailableView(
                        "Nothing to Service",
                        systemImage: "wrench.and.screwdriver",
                        description: Text("Add watches to your Vault to track their service schedule.")
                    )
                } else {
                    List {
                        if !dueWatches.isEmpty {
                            Section("Service Due") {
                                ForEach(dueWatches) { watch in
                                    MaintenanceRow(watch: watch, isDue: true)
                                }
                            }
                        }
                        if !upToDateWatches.isEmpty {
                            Section("Up to Date") {
                                ForEach(upToDateWatches) { watch in
                                    MaintenanceRow(watch: watch, isDue: false)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Maintenance")
            .navigationDestination(for: Watch.self) { watch in
                WatchDetailView(watch: watch)
            }
        }
    }
}

private struct MaintenanceRow: View {
    let watch: Watch
    let isDue: Bool

    private var statusText: String {
        if let last = watch.lastServiceDate {
            return "Last serviced \(last.formatted(date: .abbreviated, time: .omitted))"
        }
        return "Never serviced · acquired \(watch.acquisitionDate.formatted(date: .abbreviated, time: .omitted))"
    }

    var body: some View {
        NavigationLink(value: watch) {
            HStack(spacing: 12) {
                Image(systemName: isDue ? "wrench.and.screwdriver.fill" : "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(isDue ? .orange : .green)
                    .accessibilityLabel(isDue ? "Service due" : "Up to date")

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(watch.brand) \(watch.model)")
                        .font(.headline)
                    Text(statusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Watch.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let overdue = Watch(brand: "Seiko", model: "SKX007", caseDiameterMM: 42, lugToLugMM: 46, lugWidthMM: 22,
                        acquisitionDate: Calendar.current.date(byAdding: .year, value: -6, to: .now)!)
    let fresh = Watch(brand: "Omega", model: "Seamaster", caseDiameterMM: 42, lugToLugMM: 48, lugWidthMM: 20)
    container.mainContext.insert(overdue)
    container.mainContext.insert(fresh)

    return MaintenanceView()
        .modelContainer(container)
}
