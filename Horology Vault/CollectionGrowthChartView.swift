//
//  CollectionGrowthChartView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/14/26.
//

import SwiftUI
import Charts

struct CollectionGrowthChartView: View {
    let watches: [Watch]

    private struct Point: Identifiable {
        let date: Date
        let cumulativeCount: Int
        var id: Date { date }
    }

    private var points: [Point] {
        var running = 0
        return watches
            .sorted { $0.acquisitionDate < $1.acquisitionDate }
            .map { watch in
                running += 1
                return Point(date: watch.acquisitionDate, cumulativeCount: running)
            }
    }

    var body: some View {
        if points.isEmpty {
            ContentUnavailableView(
                "No Watches Yet",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Add watches to your Vault to see your collection grow over time.")
            )
        } else {
            Chart(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Watches Owned", point.cumulativeCount)
                )
                .interpolationMethod(.stepEnd)
                .symbol(.circle)
            }
            .chartYAxisLabel("watches owned")
            .frame(height: 220)
        }
    }
}

#Preview {
    CollectionGrowthChartView(watches: [])
        .padding()
}
