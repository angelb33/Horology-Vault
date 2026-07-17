//
//  PowerReserveChartView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/17/26.
//

import SwiftUI
import SwiftData
import Charts

/// Hours remaining (or overdue) until each manual/automatic watch's mainspring runs down, derived
/// from `Watch.powerReserveExpiresAt`. Quartz watches and watches missing a `movementType`/
/// `powerReserveHours` spec are excluded — same scope cut as the rest of the Winding Log feature,
/// since there's nothing to track for them.
struct PowerReserveChartView: View {
    let watches: [Watch]

    private struct Entry: Identifiable {
        let watch: Watch
        let hoursRemaining: Double
        var id: PersistentIdentifier { watch.id }
    }

    private var entries: [Entry] {
        watches
            .compactMap { watch -> Entry? in
                guard let expiresAt = watch.powerReserveExpiresAt else { return nil }
                let hours = expiresAt.timeIntervalSince(Date()) / 3600
                return Entry(watch: watch, hoursRemaining: hours)
            }
            .sorted { $0.hoursRemaining < $1.hoursRemaining }
    }

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView(
                "No Power Reserve Data",
                systemImage: "gauge.with.needle",
                description: Text("Set a movement type and power reserve on a manual or automatic watch, then wind it, to see power reserve trends here.")
            )
        } else {
            Chart(entries) { entry in
                BarMark(
                    x: .value("Hours Remaining", entry.hoursRemaining),
                    y: .value("Watch", "\(entry.watch.brand) \(entry.watch.model)")
                )
                .foregroundStyle(entry.hoursRemaining < 0 ? .red : .green)
            }
            .chartXAxisLabel("hours until depleted (negative = depleted)")
            .frame(height: 220)
        }
    }
}

#Preview {
    PowerReserveChartView(watches: [])
        .padding()
}
