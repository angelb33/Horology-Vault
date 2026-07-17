//
//  NotificationsPanelView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/17/26.
//

import SwiftUI
import SwiftData

/// A live-computed digest of watches that currently need attention — out of power, due for
/// service, or ready for pickup from maintenance. Free (see `Watch`'s notification-predicate
/// doc comments for why this doesn't cannibalize the paid Reminders feature): it only surfaces
/// facts already visible elsewhere for free (Vault card badges, `MaintenanceView`), and only
/// reflects what's already true rather than predicting what's coming up. Presented as a
/// `.popover` from the sidebar's bell button in `ContentView`.
struct NotificationsPanelView: View {
    @Query private var watches: [Watch]

    private var depletedWatches: [Watch] {
        watches.filter(\.hasOpenPowerReserveNotification)
    }

    private var serviceDueWatches: [Watch] {
        watches.filter(\.hasOpenServiceNotification)
    }

    private var readyForPickupWatches: [Watch] {
        watches.filter(\.hasOpenPickupNotification)
    }

    private var hasAnyItems: Bool {
        !depletedWatches.isEmpty || !serviceDueWatches.isEmpty || !readyForPickupWatches.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if !hasAnyItems {
                    ContentUnavailableView(
                        "All Caught Up",
                        systemImage: "checkmark.circle",
                        description: Text("No watches currently need attention.")
                    )
                } else {
                    List {
                        if !depletedWatches.isEmpty {
                            Section {
                                ForEach(depletedWatches) { watch in
                                    NotificationRow(
                                        watch: watch,
                                        message: "Out of power",
                                        systemImage: "gauge.with.needle",
                                        tint: .red
                                    )
                                }
                            } header: {
                                SectionHeader("Power Reserve")
                            }
                        }
                        if !serviceDueWatches.isEmpty || !readyForPickupWatches.isEmpty {
                            Section {
                                ForEach(serviceDueWatches) { watch in
                                    NotificationRow(
                                        watch: watch,
                                        message: "Due for service",
                                        systemImage: "wrench.and.screwdriver.fill",
                                        tint: .orange
                                    )
                                }
                                ForEach(readyForPickupWatches) { watch in
                                    NotificationRow(
                                        watch: watch,
                                        message: "Ready for pickup",
                                        systemImage: "shippingbox.fill",
                                        tint: .blue
                                    )
                                }
                            } header: {
                                SectionHeader("Maintenance")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(for: Watch.self) { watch in
                WatchDetailView(watch: watch)
            }
        }
        #if os(macOS)
        .frame(minWidth: 340, idealWidth: 360, minHeight: 320, idealHeight: 420)
        #endif
        // Closing the popover is what counts as "acknowledged" — matches how the OS's own
        // notification center clears its badge once you've viewed the list, without needing a
        // separate explicit "mark as read" action. Nothing in the list itself is affected; only
        // the sidebar bell's badge count changes on the next open.
        .onDisappear {
            NotificationsAcknowledgment.acknowledgeAll(watches)
        }
    }
}

private struct NotificationRow: View {
    let watch: Watch
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        NavigationLink(value: watch) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(watch.brand) \(watch.model)")
                        .font(.headline)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

#Preview {
    NotificationsPanelView()
        .modelContainer(for: Watch.self, inMemory: true)
}
