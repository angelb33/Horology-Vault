//
//  AccuracyChartView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/10/26.
//

import SwiftUI
import Charts

struct AccuracyChartView: View {
    let serviceRecords: [ServiceRecord]

    private var sortedRecords: [ServiceRecord] {
        serviceRecords.sorted { $0.datePerformed < $1.datePerformed }
    }

    var body: some View {
        if sortedRecords.isEmpty {
            ContentUnavailableView(
                "No Service History",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Accuracy drift will appear here once a service is logged.")
            )
        } else {
            Chart(sortedRecords) { record in
                LineMark(
                    x: .value("Date", record.datePerformed),
                    y: .value("Accuracy (sec/day)", record.accuracyDeltaSPD)
                )
                .symbol(.circle)
            }
            .chartYAxisLabel("sec/day")
            .frame(height: 180)
        }
    }
}

#Preview {
    AccuracyChartView(serviceRecords: [])
        .padding()
}
