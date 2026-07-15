//
//  CostPerWearChartView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 2026-07-16.
//

import SwiftUI
import Charts

struct CostPerWearChartView: View {
    let watches: [Watch]

    private var sortedCostPerWear: [(watch: Watch, cost: Double)] {
        watches
            .compactMap { watch in watch.costPerWear.map { (watch: watch, cost: $0) } }
            .sorted { $0.cost < $1.cost } // cheapest cost-per-wear first — a "best value" leaderboard,
                                           // same positive framing WearFrequencyChartView uses
    }

    var body: some View {
        if sortedCostPerWear.isEmpty {
            ContentUnavailableView(
                "No Purchase Prices Set",
                systemImage: "dollarsign.circle",
                description: Text("Add a purchase price when editing a watch you've worn at least once to see cost-per-wear here.")
            )
        } else {
            Chart(sortedCostPerWear, id: \.watch.id) { entry in
                BarMark(
                    x: .value("Cost per Wear", entry.cost),
                    y: .value("Watch", "\(entry.watch.brand) \(entry.watch.model)")
                )
            }
            .chartXAxisLabel("cost per wear")
            .frame(height: 220)
        }
    }
}

#Preview {
    CostPerWearChartView(watches: [])
        .padding()
}
