//
//  DepletedWatchesChartView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/17/26.
//

import SwiftUI
import SwiftData
import Charts

/// How many days each currently-depleted manual/automatic watch has been out of power, derived
/// from `Watch.daysSincePowerReserveDepleted`. Unlike `PowerReserveChartView` (every trackable
/// watch, hours remaining or overdue), this chart is scoped to only the watches that actually
/// need winding right now — a focused "what needs my attention" view rather than a full status
/// board, on the theory that a long-depleted watch is more actionable than one still comfortably
/// powered.
struct DepletedWatchesChartView: View {
    let watches: [Watch]

    private struct Entry: Identifiable {
        let watch: Watch
        let daysSinceDepleted: Int
        var id: PersistentIdentifier { watch.id }
    }

    private var entries: [Entry] {
        watches
            .compactMap { watch -> Entry? in
                guard let days = watch.daysSincePowerReserveDepleted else { return nil }
                return Entry(watch: watch, daysSinceDepleted: days)
            }
            .sorted { $0.daysSinceDepleted > $1.daysSinceDepleted }
    }

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView(
                "All Watches Powered",
                systemImage: "checkmark.circle",
                description: Text("None of your manual or automatic watches are currently out of power.")
            )
        } else {
            Chart(entries) { entry in
                BarMark(
                    x: .value("Days Out of Power", entry.daysSinceDepleted),
                    y: .value("Watch", "\(entry.watch.brand) \(entry.watch.model)")
                )
                .foregroundStyle(.red)
            }
            .chartXAxisLabel("days out of power")
            .frame(height: 220)
        }
    }
}

#Preview {
    DepletedWatchesChartView(watches: [])
        .padding()
}
