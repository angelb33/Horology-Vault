//
//  AddWatchView.swift
//  Horology Vault"
//
//  Created by Angel Burgos on 7/11/26.
//

import SwiftUI
import SwiftData
import PhotosUI

struct AddWatchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var brand = ""
    @State private var model = ""
    @State private var selectedComplications: Set<String> = []
    @State private var caseDiameterMM: Double?
    @State private var lugToLugMM: Double?
    @State private var lugWidthMM: Double?

    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?

    /// A small curated set of common complications keeps entry to a couple of taps
    /// rather than free-form typing, while still covering the vast majority of watches.
    private let commonComplications = [
        "Date", "Day-Date", "Chronograph", "GMT", "Moonphase",
        "Power Reserve", "World Time", "Perpetual Calendar", "Tourbillon", "Alarm"
    ]

    private var canSave: Bool {
        !brand.trimmingCharacters(in: .whitespaces).isEmpty
            && !model.trimmingCharacters(in: .whitespaces).isEmpty
            && (caseDiameterMM ?? 0) > 0
            && (lugToLugMM ?? 0) > 0
            && (lugWidthMM ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                complicationsSection
                measurementsSection
                photoSection
            }
            .navigationTitle("Add Watch")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
            .task(id: photoItem) {
                photoData = try? await photoItem?.loadTransferable(type: Data.self)
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Brand", text: $brand)
            TextField("Model", text: $model)
        }
    }

    private var complicationsSection: some View {
        Section("Complications") {
            ForEach(commonComplications, id: \.self) { complication in
                Toggle(complication, isOn: Binding(
                    get: { selectedComplications.contains(complication) },
                    set: { isOn in
                        if isOn { selectedComplications.insert(complication) }
                        else { selectedComplications.remove(complication) }
                    }
                ))
            }
        }
    }

    private var measurementsSection: some View {
        Section("Measurements") {
            MeasurementField(label: "Case Diameter", unit: "mm", value: $caseDiameterMM)
            MeasurementField(label: "Lug-to-Lug", unit: "mm", value: $lugToLugMM)
            MeasurementField(label: "Lug Width", unit: "mm", value: $lugWidthMM)
        }
    }

    private var photoSection: some View {
        Section("Photo") {
            PhotosPicker(selection: $photoItem, matching: .images) {
                if let photoData, let image = platformImage(from: photoData) {
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Label("Choose Photo", systemImage: "photo.badge.plus")
                }
            }
            if photoData != nil {
                Button("Remove Photo", role: .destructive) {
                    photoItem = nil
                    photoData = nil
                }
            }
        }
    }

    private func save() {
        let watch = Watch(
            brand: brand.trimmingCharacters(in: .whitespaces),
            model: model.trimmingCharacters(in: .whitespaces),
            complications: commonComplications.filter { selectedComplications.contains($0) },
            caseDiameterMM: caseDiameterMM ?? 0,
            lugToLugMM: lugToLugMM ?? 0,
            lugWidthMM: lugWidthMM ?? 0,
            photoData: photoData
        )
        modelContext.insert(watch)
        dismiss()
    }
}

/// Reusable labeled numeric entry with a trailing unit, right-aligned for a clean
/// column of measurements. Uses the decimal pad on iOS where one exists.
private struct MeasurementField: View {
    let label: String
    let unit: String
    @Binding var value: Double?

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: $value, format: .number)
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .frame(maxWidth: 80)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }
}

private func platformImage(from data: Data) -> Image? {
    #if os(iOS)
    guard let uiImage = UIImage(data: data) else { return nil }
    return Image(uiImage: uiImage)
    #elseif os(macOS)
    guard let nsImage = NSImage(data: data) else { return nil }
    return Image(nsImage: nsImage)
    #else
    return nil
    #endif
}

#Preview {
    AddWatchView()
        .modelContainer(for: Watch.self, inMemory: true)
}
