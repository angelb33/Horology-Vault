//
//  DashboardView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/14/26.
//

import SwiftUI
import SwiftData
import StoreKit

/// Root view for the sidebar's "Insights" entry — a scrollable set of collection-wide trend charts,
/// all derived from data the app already collects (`WearLog`, `ServiceRecord`, `Watch`). Unlike the
/// Vault (open to everyone, since blocking watch creation itself hurts onboarding more than it drives
/// conversion), Insights is the feature gated behind the one-time purchase — it's a "grows with your
/// collection" analytics layer, not something a browser needs to evaluate before buying.
struct DashboardView: View {
    @Environment(PurchaseManager.self) private var purchaseManager
    @Query private var watches: [Watch]
    @Query private var entitlements: [Entitlements]

    private var isUnlocked: Bool {
        entitlements.first?.isLifetimeUnlocked ?? false
    }

    var body: some View {
        NavigationStack {
            Group {
                if !isUnlocked {
                    lockedView
                } else if watches.isEmpty {
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

    private var lockedView: some View {
        ContentUnavailableView {
            Label("Insights is a Full Version Feature", systemImage: "lock")
        } description: {
            Text("Unlock the full version to see wear frequency, service status, and maintenance trends across your collection.")
        } actions: {
            Button {
                Task { await purchaseManager.purchase() }
            } label: {
                if let product = purchaseManager.product {
                    Text("Unlock Full Version — \(product.displayPrice)")
                } else {
                    Text("Unlock Full Version")
                }
            }
            .buttonStyle(.borderedProminent)
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
        for: Watch.self, Entitlements.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let watch = Watch(brand: "Rolex", model: "Explorer", caseDiameterMM: 36, lugToLugMM: 44, lugWidthMM: 20)
    container.mainContext.insert(watch)
    container.mainContext.insert(Entitlements(isLifetimeUnlocked: true))

    return DashboardView()
        .modelContainer(container)
        .environment(PurchaseManager())
}
