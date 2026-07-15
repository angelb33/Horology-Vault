//
//  AddWatchView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/11/26.
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct AddWatchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// The watch being edited, if any. Nil means this sheet is creating a new watch.
    private let watchToEdit: Watch?

    @State private var brand: String
    @State private var model: String
    @State private var referenceNumber: String
    @State private var selectedComplications: Set<String>
    @State private var caseDiameterMM: Double?
    @State private var lugToLugMM: Double?
    @State private var lugWidthMM: Double?
    @State private var purchasePrice: Double?

    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    #if os(macOS)
    // PhotosPicker only browses the macOS Photos library, not arbitrary Finder
    // folders like ~/Pictures, so macOS uses a file importer instead to reach
    // any image file on disk.
    @State private var isImportingPhoto = false
    #endif

    init(watchToEdit: Watch? = nil) {
        self.watchToEdit = watchToEdit
        _brand = State(initialValue: watchToEdit?.brand ?? "")
        _model = State(initialValue: watchToEdit?.model ?? "")
        _referenceNumber = State(initialValue: watchToEdit?.referenceNumber ?? "")
        _selectedComplications = State(initialValue: Set(watchToEdit?.complications ?? []))
        _caseDiameterMM = State(initialValue: watchToEdit?.caseDiameterMM)
        _lugToLugMM = State(initialValue: watchToEdit?.lugToLugMM)
        _lugWidthMM = State(initialValue: watchToEdit?.lugWidthMM)
        _photoData = State(initialValue: watchToEdit?.photoData)
        _purchasePrice = State(initialValue: watchToEdit?.purchasePrice)
    }

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
            #if os(macOS)
            // The default macOS Form style left-aligns its sections in a narrow
            // column instead of centering them like System Settings; .grouped
            // matches that centered, card-style layout.
            .formStyle(.grouped)
            #endif
            .navigationTitle(watchToEdit == nil ? "Add Watch" : "Edit Watch")
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
            #if os(macOS)
            .fileImporter(isPresented: $isImportingPhoto, allowedContentTypes: [.image]) { result in
                guard let url = try? result.get() else { return }
                let didAccess = url.startAccessingSecurityScopedResource()
                defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                photoData = try? Data(contentsOf: url)
            }
            #endif
        }
        #if os(macOS)
        // Without an explicit frame, a Form-based sheet sizes itself to its content's
        // minimum size on macOS, which renders small and off-center instead of as a
        // properly proportioned modal.
        .frame(minWidth: 420, idealWidth: 460, minHeight: 480, idealHeight: 560)
        #endif
    }

    private var detailsSection: some View {
        Section {
            TextField("Brand", text: $brand)
            TextField("Model", text: $model)
            TextField("Reference Number", text: $referenceNumber)
            LabeledContent("Purchase Price") {
                TextField("Optional", value: $purchasePrice, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .multilineTextAlignment(.trailing)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .frame(maxWidth: 120)
            }
        } header: {
            SectionHeader("Details")
        }
    }

    private var complicationsSection: some View {
        Section {
            ForEach(Watch.commonComplications, id: \.self) { complication in
                Toggle(complication, isOn: Binding(
                    get: { selectedComplications.contains(complication) },
                    set: { isOn in
                        if isOn { selectedComplications.insert(complication) }
                        else { selectedComplications.remove(complication) }
                    }
                ))
            }
        } header: {
            SectionHeader("Complications")
        }
    }

    private var measurementsSection: some View {
        Section {
            MeasurementField(label: "Case Diameter", unit: "mm", value: $caseDiameterMM)
            MeasurementField(label: "Lug-to-Lug", unit: "mm", value: $lugToLugMM)
            MeasurementField(label: "Lug Width", unit: "mm", value: $lugWidthMM)
        } header: {
            SectionHeader("Measurements")
        }
    }

    private var photoSection: some View {
        Section {
            #if os(macOS)
            Button {
                isImportingPhoto = true
            } label: {
                photoPreview
            }
            .buttonStyle(.plain)
            #else
            PhotosPicker(selection: $photoItem, matching: .images) {
                photoPreview
            }
            #endif
            if photoData != nil {
                Button("Remove Photo", role: .destructive) {
                    photoItem = nil
                    photoData = nil
                }
            }
        } header: {
            SectionHeader("Photo")
        }
    }

    @ViewBuilder
    private var photoPreview: some View {
        if let photoData, let image = platformImage(from: photoData) {
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            Label("Choose Photo", systemImage: "photo.badge.plus")
        }
    }

    private func save() {
        let trimmedReference = referenceNumber.trimmingCharacters(in: .whitespaces)
        let trimmedBrand = brand.trimmingCharacters(in: .whitespaces)
        let trimmedModel = model.trimmingCharacters(in: .whitespaces)
        let complications = Watch.commonComplications.filter { selectedComplications.contains($0) }

        let targetWatch: Watch
        if let watchToEdit {
            watchToEdit.brand = trimmedBrand
            watchToEdit.model = trimmedModel
            watchToEdit.referenceNumber = trimmedReference.isEmpty ? nil : trimmedReference
            watchToEdit.complications = complications
            watchToEdit.caseDiameterMM = caseDiameterMM ?? 0
            watchToEdit.lugToLugMM = lugToLugMM ?? 0
            watchToEdit.lugWidthMM = lugWidthMM ?? 0
            watchToEdit.photoData = photoData
            watchToEdit.purchasePrice = purchasePrice
            targetWatch = watchToEdit
        } else {
            let watch = Watch(
                brand: trimmedBrand,
                model: trimmedModel,
                referenceNumber: trimmedReference.isEmpty ? nil : trimmedReference,
                complications: complications,
                caseDiameterMM: caseDiameterMM ?? 0,
                lugToLugMM: lugToLugMM ?? 0,
                lugWidthMM: lugWidthMM ?? 0,
                photoData: photoData,
                purchasePrice: purchasePrice
            )
            modelContext.insert(watch)
            targetWatch = watch
        }
        NotificationManager.scheduleServiceDueReminder(for: targetWatch)
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
        LabeledContent(label) {
            HStack(spacing: 4) {
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
