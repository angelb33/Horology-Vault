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
    @Query private var entitlements: [Entitlements]

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
    @State private var movementType: MovementType?
    @State private var powerReserveHours: Double?
    @State private var windReminderLeadTimeHours: Double?

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
        _movementType = State(initialValue: watchToEdit?.movementType)
        _powerReserveHours = State(initialValue: watchToEdit?.powerReserveHours)
        _windReminderLeadTimeHours = State(initialValue: watchToEdit?.windReminderLeadTimeHours)
    }

    private var canSave: Bool {
        !brand.trimmingCharacters(in: .whitespaces).isEmpty
            && !model.trimmingCharacters(in: .whitespaces).isEmpty
            && (caseDiameterMM ?? 0) > 0
            && (lugToLugMM ?? 0) > 0
            && (lugWidthMM ?? 0) > 0
    }

    /// `powerReserveHours` only means something for movements that actually hold a wind —
    /// clears it out if the user switches away from Manual/Automatic rather than leaving a
    /// stale value hidden on the record.
    private var effectivePowerReserveHours: Double? {
        guard movementType == .manual || movementType == .automatic else { return nil }
        return powerReserveHours
    }

    /// Same clearing rule as `effectivePowerReserveHours` — a lead time only means something
    /// alongside a power reserve spec.
    private var effectiveWindReminderLeadTimeHours: Double? {
        guard movementType == .manual || movementType == .automatic else { return nil }
        return windReminderLeadTimeHours
    }

    /// Service Due and Wind reminders are both gated behind the lifetime unlock (see
    /// `NotificationManager`'s doc comment) — this only affects whether the app actually
    /// notifies the user, not whether the reminder fields below can be entered, so a free
    /// user's data isn't lost if they later unlock.
    private var isUnlocked: Bool {
        entitlements.first?.isLifetimeUnlocked ?? false
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                movementSection
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

    private var movementSection: some View {
        Section {
            Picker("Movement Type", selection: $movementType) {
                Text("Not Set").tag(MovementType?.none)
                ForEach(MovementType.allCases) { type in
                    Text(type.rawValue).tag(MovementType?.some(type))
                }
            }
            if movementType == .manual || movementType == .automatic {
                LabeledContent("Power Reserve") {
                    HStack(spacing: 4) {
                        TextField("0", value: $powerReserveHours, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .frame(maxWidth: 80)
                        Text("hours")
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Wind Reminder") {
                    HStack(spacing: 4) {
                        TextField("0", value: $windReminderLeadTimeHours, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .frame(maxWidth: 80)
                        Text("hours before empty")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            SectionHeader("Movement")
        } footer: {
            // Power reserve and the reminder lead time are always free to enter — see
            // `isUnlocked`'s doc comment — this just clarifies that the notification itself
            // needs the full version, without blocking data entry. No purchase button here;
            // that flow already lives in Settings/Insights, this is informational only.
            if (movementType == .manual || movementType == .automatic) && !isUnlocked {
                Label("Reminders are a Full Version feature — power reserve is still tracked for free. Unlock in Settings to get notified before it runs out.", systemImage: "lock")
            }
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
            watchToEdit.movementType = movementType
            watchToEdit.powerReserveHours = effectivePowerReserveHours
            watchToEdit.windReminderLeadTimeHours = effectiveWindReminderLeadTimeHours
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
                purchasePrice: purchasePrice,
                movementType: movementType,
                powerReserveHours: effectivePowerReserveHours,
                windReminderLeadTimeHours: effectiveWindReminderLeadTimeHours
            )
            modelContext.insert(watch)
            targetWatch = watch
        }
        NotificationManager.scheduleServiceDueReminder(for: targetWatch, isUnlocked: isUnlocked)
        NotificationManager.scheduleWindReminder(for: targetWatch, isUnlocked: isUnlocked)
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
        .modelContainer(for: [Watch.self, Entitlements.self], inMemory: true)
}
