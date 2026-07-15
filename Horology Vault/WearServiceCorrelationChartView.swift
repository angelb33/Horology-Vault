//
//  WearServiceCorrelationChartView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/14/26.
//

import SwiftUI
import SwiftData
import Charts

/// Plots how much wear a watch has accumulated since its last service against how long it's been
/// since that service — flags watches getting heavy use without a matching maintenance interval,
/// rather than just reporting wear counts or service dates in isolation.
struct WearServiceCorrelationChartView: View {
    let watches: [Watch]

    private struct Entry: Identifiable {
        let watch: Watch
        let daysSinceService: Int
        let wearCount: Int
        var id: PersistentIdentifier { watch.id }
    }

    private var entries: [Entry] {
        watches
            .map { watch -> Entry in
                let since = watch.lastServiceDate ?? watch.acquisitionDate
                let days = Calendar.current.dateComponents([.day], from: since, to: Date()).day ?? 0
                return Entry(watch: watch, daysSinceService: max(days, 0), wearCount: watch.wearCountSinceLastService)
            }
            .filter { $0.wearCount > 0 }
    }

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView(
                "No Wear Logged",
                systemImage: "chart.dots.scatter",
                description: Text("Log wear on a watch to see how it's holding up since its last service.")
            )
        } else {
            Chart(entries) { entry in
                PointMark(
                    x: .value("Days Since Service", entry.daysSinceService),
                    y: .value("Times Worn Since Service", entry.wearCount)
                )
                .symbolSize(80)
                .annotation(position: .top) {
                    Text("\(entry.watch.brand) \(entry.watch.model)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxisLabel("days since last service")
            .chartYAxisLabel("times worn since")
            .frame(height: 240)
        }
    }
}

#Preview {
    WearServiceCorrelationChartView(watches: [])
        .padding()
}
