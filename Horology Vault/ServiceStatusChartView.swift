//
//  ServiceStatusChartView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/14/26.
//

import SwiftUI
import SwiftData
import Charts

struct ServiceStatusChartView: View {
    let watches: [Watch]

    private struct Entry: Identifiable {
        let watch: Watch
        let daysUntilDue: Int
        var id: PersistentIdentifier { watch.id }
    }

    private var entries: [Entry] {
        watches
            .compactMap { watch -> Entry? in
                guard let dueDate = watch.serviceDueDate else { return nil }
                let days = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
                return Entry(watch: watch, daysUntilDue: days)
            }
            .sorted { $0.daysUntilDue < $1.daysUntilDue }
    }

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView(
                "No Watches Yet",
                systemImage: "wrench.and.screwdriver",
                description: Text("Add watches to your Vault to track service status here.")
            )
        } else {
            Chart(entries) { entry in
                BarMark(
                    x: .value("Days Until Due", entry.daysUntilDue),
                    y: .value("Watch", "\(entry.watch.brand) \(entry.watch.model)")
                )
                .foregroundStyle(entry.daysUntilDue < 0 ? .red : .green)
            }
            .chartXAxisLabel("days until due (negative = overdue)")
            .frame(height: 220)
        }
    }
}

#Preview {
    ServiceStatusChartView(watches: [])
        .padding()
}
