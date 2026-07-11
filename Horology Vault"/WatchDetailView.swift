//
//  WatchDetailView.swift
//  Horology Vault"
//
//  Created by Angel Burgos on 7/10/26.
//

import SwiftUI
import SwiftData

struct WatchDetailView: View {
    @Bindable var watch: Watch

    @Query private var allStraps: [Strap]
    @Query private var userProfiles: [UserProfile]

    private var compatibleStraps: [Strap] {
        allStraps.filter { $0.widthMM == watch.lugWidthMM }
    }

    var body: some View {
        Form {
            overviewSection
            strapsSection
            serviceHistorySection
            wearLogSection
            provenanceSection
            fitPreviewSection
        }
        .navigationTitle("\(watch.brand) \(watch.model)")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var overviewSection: some View {
        Section("Overview") {
            LabeledContent("Brand", value: watch.brand)
            LabeledContent("Model", value: watch.model)
            if !watch.complications.isEmpty {
                LabeledContent("Complications", value: watch.complications.joined(separator: ", "))
            }
            LabeledContent("Case Diameter", value: "\(watch.caseDiameterMM.formatted()) mm")
            LabeledContent("Lug-to-Lug", value: "\(watch.lugToLugMM.formatted()) mm")
            LabeledContent("Lug Width", value: "\(watch.lugWidthMM.formatted()) mm")
            LabeledContent("Acquired", value: watch.acquisitionDate.formatted(date: .abbreviated, time: .omitted))
        }
    }

    private var strapsSection: some View {
        Section("Straps") {
            if let attached = watch.attachedStrap {
                LabeledContent("Attached", value: "\(attached.material) \u{b7} \(attached.widthMM.formatted()) mm")
                Button("Detach", role: .destructive) {
                    watch.attachedStrap = nil
                }
            } else {
                Text("No strap attached")
                    .foregroundStyle(.secondary)
            }

            if !compatibleStraps.isEmpty {
                Picker("Attach Strap", selection: Binding(
                    get: { watch.attachedStrap },
                    set: { watch.attachedStrap = $0 }
                )) {
                    Text("None").tag(Strap?.none)
                    ForEach(compatibleStraps) { strap in
                        Text("\(strap.material) \u{b7} \(strap.widthMM.formatted()) mm").tag(Strap?.some(strap))
                    }
                }
            }
        }
    }

    private var serviceHistorySection: some View {
        Section("Service History") {
            AccuracyChartView(serviceRecords: watch.serviceRecords)

            ForEach(watch.serviceRecords.sorted(by: { $0.datePerformed > $1.datePerformed })) { record in
                VStack(alignment: .leading) {
                    Text(record.serviceType)
                        .font(.headline)
                    Text(record.datePerformed.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var wearLogSection: some View {
        Section("Wear Log") {
            Text("Wear tracking is coming soon.")
                .foregroundStyle(.secondary)
        }
    }

    private var provenanceSection: some View {
        Section("Provenance") {
            Text("Receipts, warranty cards, and appraisals will live here.")
                .foregroundStyle(.secondary)
        }
    }

    private var fitPreviewSection: some View {
        Section("Fit Preview") {
            if let profile = userProfiles.first {
                LabeledContent("Lug-to-Lug", value: "\(watch.lugToLugMM.formatted()) mm")
                LabeledContent("Wrist Width", value: "\(profile.wristTopWidthCM.formatted()) cm")
            } else {
                Text("Add your wrist measurements in Settings to preview fit.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        WatchDetailView(watch: Watch(brand: "Rolex", model: "Explorer", caseDiameterMM: 36, lugToLugMM: 44, lugWidthMM: 19))
    }
    .modelContainer(for: Watch.self, inMemory: true)
}
