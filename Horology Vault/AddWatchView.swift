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

    @State private var serialNumber: String
    @State private var caliber: String
    @State private var caseMaterial: String
    @State private var dialColor: String
    @State private var waterResistanceMeters: Int?
    @State private var boxAndPapersStatus: BoxAndPapersStatus?
    @State private var condition: WatchCondition?
    @State private var hasWarrantyExpirationDate: Bool
    @State private var warrantyExpirationDate: Date
    @State private var insuredValue: Double?
    @State private var hasAppraisalDate: Bool
    @State private var appraisalDate: Date

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
        _serialNumber = State(initialValue: watchToEdit?.serialNumber ?? "")
        _caliber = State(initialValue: watchToEdit?.caliber ?? "")
        _caseMaterial = State(initialValue: watchToEdit?.caseMaterial ?? "")
        _dialColor = State(initialValue: watchToEdit?.dialColor ?? "")
        _waterResistanceMeters = State(initialValue: watchToEdit?.waterResistanceMeters)
        _boxAndPapersStatus = State(initialValue: watchToEdit?.boxAndPapersStatus)
        _condition = State(initialValue: watchToEdit?.condition)
        _hasWarrantyExpirationDate = State(initialValue: watchToEdit?.warrantyExpirationDate != nil)
        _warrantyExpirationDate = State(initialValue: watchToEdit?.warrantyExpirationDate ?? Date())
        _insuredValue = State(initialValue: watchToEdit?.insuredValue)
        _hasAppraisalDate = State(initialValue: watchToEdit?.appraisalDate != nil)
        _appraisalDate = State(initialValue: watchToEdit?.appraisalDate ?? Date())
    }

    private var canSave: Bool {
        !brand.trimmingCharacters(in: .whitespaces).isEmpty
            && !model.trimmingCharacters(in: .whitespaces).isEmpty
            && (caseDiameterMM ?? 0) > 0
            && (lugToLugMM ?? 0) > 0
            && (lugWidthMM ?? 0) > 0
            && isWindReminderLeadTimeValid
    }

    /// A wind reminder that fires at or after the power reserve is already exhausted defeats the
    /// purpose of a "before it runs out" warning, so this must be strictly less than
    /// `powerReserveHours` whenever both are set. Vacuously true (nothing to validate) once
    /// either value is missing or the movement type doesn't use power reserve at all.
    private var isWindReminderLeadTimeValid: Bool {
        guard movementType == .manual || movementType == .automatic,
              let windReminderLeadTimeHours, let powerReserveHours
        else { return true }
        return windReminderLeadTimeHours < powerReserveHours
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

    /// `DatePicker` can't bind directly to `Date?`, so these optional date fields pair a concrete
    /// `Date` `@State` with a `Bool` "has a value" toggle — `nil` unless the toggle is on.
    private var effectiveWarrantyExpirationDate: Date? {
        hasWarrantyExpirationDate ? warrantyExpirationDate : nil
    }

    private var effectiveAppraisalDate: Date? {
        hasAppraisalDate ? appraisalDate : nil
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
                specificationsSection
                conditionAndDocumentationSection
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
            TextField("Serial Number", text: $serialNumber)
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

    private var specificationsSection: some View {
        Section {
            TextField("Caliber", text: $caliber)
            TextField("Case Material", text: $caseMaterial)
            TextField("Dial Color", text: $dialColor)
            LabeledContent("Water Resistance") {
                HStack(spacing: 4) {
                    TextField("0", value: $waterResistanceMeters, format: .number)
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .frame(maxWidth: 80)
                    Text("meters")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            SectionHeader("Specifications")
        }
    }

    private var conditionAndDocumentationSection: some View {
        Section {
            Picker("Condition", selection: $condition) {
                Text("Not Set").tag(WatchCondition?.none)
                ForEach(WatchCondition.allCases) { grade in
                    Text(grade.rawValue).tag(WatchCondition?.some(grade))
                }
            }
            Picker("Box & Papers", selection: $boxAndPapersStatus) {
                Text("Not Set").tag(BoxAndPapersStatus?.none)
                ForEach(BoxAndPapersStatus.allCases) { status in
                    Text(status.rawValue).tag(BoxAndPapersStatus?.some(status))
                }
            }
            Toggle("Warranty Expiration", isOn: $hasWarrantyExpirationDate)
            if hasWarrantyExpirationDate {
                DatePicker("Expires", selection: $warrantyExpirationDate, displayedComponents: .date)
            }
            LabeledContent("Insured Value") {
                TextField("Optional", value: $insuredValue, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .multilineTextAlignment(.trailing)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .frame(maxWidth: 120)
            }
            Toggle("Appraisal Date", isOn: $hasAppraisalDate)
            if hasAppraisalDate {
                DatePicker("Appraised", selection: $appraisalDate, displayedComponents: .date)
            }
        } header: {
            SectionHeader("Condition & Documentation")
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
            VStack(alignment: .leading, spacing: 6) {
                if !isWindReminderLeadTimeValid {
                    Label("Wind Reminder must be less than Power Reserve — a reminder that fires at or after the watch is already depleted isn't useful.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
                // Power reserve and the reminder lead time are always free to enter — see
                // `isUnlocked`'s doc comment — this just clarifies that the notification itself
                // needs the full version, without blocking data entry. No purchase button here;
                // that flow already lives in Settings/Insights, this is informational only.
                if (movementType == .manual || movementType == .automatic) && !isUnlocked {
                    Label("Reminders are a Full Version feature — power reserve is still tracked for free. Unlock in Settings to get notified before it runs out.", systemImage: "lock")
                }
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
        let trimmedSerialNumber = serialNumber.trimmingCharacters(in: .whitespaces)
        let trimmedCaliber = caliber.trimmingCharacters(in: .whitespaces)
        let trimmedCaseMaterial = caseMaterial.trimmingCharacters(in: .whitespaces)
        let trimmedDialColor = dialColor.trimmingCharacters(in: .whitespaces)
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
            watchToEdit.serialNumber = trimmedSerialNumber.isEmpty ? nil : trimmedSerialNumber
            watchToEdit.caliber = trimmedCaliber.isEmpty ? nil : trimmedCaliber
            watchToEdit.caseMaterial = trimmedCaseMaterial.isEmpty ? nil : trimmedCaseMaterial
            watchToEdit.dialColor = trimmedDialColor.isEmpty ? nil : trimmedDialColor
            watchToEdit.waterResistanceMeters = waterResistanceMeters
            watchToEdit.boxAndPapersStatus = boxAndPapersStatus
            watchToEdit.condition = condition
            watchToEdit.warrantyExpirationDate = effectiveWarrantyExpirationDate
            watchToEdit.insuredValue = insuredValue
            watchToEdit.appraisalDate = effectiveAppraisalDate
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
                windReminderLeadTimeHours: effectiveWindReminderLeadTimeHours,
                serialNumber: trimmedSerialNumber.isEmpty ? nil : trimmedSerialNumber,
                caliber: trimmedCaliber.isEmpty ? nil : trimmedCaliber,
                caseMaterial: trimmedCaseMaterial.isEmpty ? nil : trimmedCaseMaterial,
                dialColor: trimmedDialColor.isEmpty ? nil : trimmedDialColor,
                waterResistanceMeters: waterResistanceMeters,
                boxAndPapersStatus: boxAndPapersStatus,
                condition: condition,
                warrantyExpirationDate: effectiveWarrantyExpirationDate,
                insuredValue: insuredValue,
                appraisalDate: effectiveAppraisalDate
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
