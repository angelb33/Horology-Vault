//
//  WearFrequencyChartView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/14/26.
//

import SwiftUI
import Charts

struct WearFrequencyChartView: View {
    let watches: [Watch]

    private var sortedCounts: [(watch: Watch, count: Int)] {
        watches
            .map { (watch: $0, count: $0.wearLogs.count) }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        if sortedCounts.isEmpty {
            ContentUnavailableView(
                "No Wear Logged",
                systemImage: "calendar.badge.clock",
                description: Text("Log wear on a watch to see how often each piece gets worn.")
            )
        } else {
            Chart(sortedCounts, id: \.watch.id) { entry in
                BarMark(
                    x: .value("Times Worn", entry.count),
                    y: .value("Watch", "\(entry.watch.brand) \(entry.watch.model)")
                )
            }
            .frame(height: 220)
        }
    }
}

#Preview {
    WearFrequencyChartView(watches: [])
        .padding()
}
