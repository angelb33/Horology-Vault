//
//  DashboardView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/14/26.
//

import SwiftUI
import SwiftData

/// Root view for the sidebar's "Insights" entry — a scrollable set of collection-wide trend charts,
/// all derived from data the app already collects (`WearLog`, `ServiceRecord`, `Watch`).
struct DashboardView: View {
    @Query private var watches: [Watch]

    var body: some View {
        NavigationStack {
            Group {
                if watches.isEmpty {
                    ContentUnavailableView(
                        "No Watches Yet",
                        systemImage: "chart.bar.xaxis",
                        description: Text("Add watches to your Vault to see wear and maintenance trends here.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            InsightCard(title: "Wear Frequency") {
                                WearFrequencyChartView(watches: watches)
                            }
                            InsightCard(title: "Service Status") {
                                ServiceStatusChartView(watches: watches)
                            }
                            InsightCard(title: "Wear vs. Maintenance") {
                                WearServiceCorrelationChartView(watches: watches)
                            }
                            InsightCard(title: "Collection Growth") {
                                CollectionGrowthChartView(watches: watches)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Insights")
        }
    }
}

private struct InsightCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Watch.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let watch = Watch(brand: "Rolex", model: "Explorer", caseDiameterMM: 36, lugToLugMM: 44, lugWidthMM: 20)
    container.mainContext.insert(watch)

    return DashboardView()
        .modelContainer(container)
}
