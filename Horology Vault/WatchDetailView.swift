//
//  WatchDetailView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/10/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct WatchDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var watch: Watch

    @Query private var allStraps: [Strap]
    @Query private var userProfiles: [UserProfile]
    @Query private var entitlements: [Entitlements]

    // Read-only here (Settings owns writing these) — used to grey out this watch's own reminder
    // controls when the matching app-wide master switch is off, since those controls have no
    // effect in that state. See NotificationManager's doc comment for the AND-gate relationship.
    @AppStorage(NotificationManager.isServiceDueReminderEnabledKey) private var isServiceDueReminderEnabledGlobally = true
    @AppStorage(NotificationManager.isWindReminderEnabledKey) private var isWindReminderEnabledGlobally = true

    private var compatibleStraps: [Strap] {
        allStraps.filter { $0.widthMM == watch.lugWidthMM }
    }

    private var isUnlocked: Bool {
        entitlements.first?.isLifetimeUnlocked ?? false
    }

    @State private var isEditing = false
    @State private var isAddingStrap = false
    @State private var editingStrap: Strap?
    @State private var isLoggingService = false
    @State private var isAddingProvenanceDoc = false
    @State private var isConfirmingDelete = false
    @State private var isDroppingOffForMaintenance = false

    var body: some View {
        Form {
            overviewSection
            specificationsSection
            conditionAndDocumentationSection
            remindersSection
            strapsSection
            maintenanceSection
            serviceHistorySection
            wearLogSection
            powerReserveSection
            provenanceSection
            fitPreviewSection
        }
        #if os(macOS)
        // The default macOS Form style left-aligns its sections in a narrow
        // column instead of centering them like System Settings; .grouped
        // matches that centered, card-style layout.
        .formStyle(.grouped)
        #endif
        .navigationTitle("\(watch.brand) \(watch.model)")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    isConfirmingDelete = true
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            AddWatchView(watchToEdit: watch)
        }
        .sheet(isPresented: $isAddingStrap) {
            AddStrapView(watch: watch)
        }
        .sheet(item: $editingStrap) { strap in
            AddStrapView(watch: watch, strapToEdit: strap)
        }
        .sheet(isPresented: $isLoggingService) {
            AddServiceRecordView(watch: watch)
        }
        .sheet(isPresented: $isAddingProvenanceDoc) {
            AddProvenanceDocView(watch: watch)
        }
        .sheet(isPresented: $isDroppingOffForMaintenance) {
            DropOffForMaintenanceView(watch: watch)
        }
        .confirmationDialog(
            "Delete \(watch.brand) \(watch.model)?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                NotificationManager.cancelServiceDueReminder(for: watch)
                NotificationManager.cancelWindReminder(for: watch)
                NotificationManager.cancelPickupReminder(for: watch)
                modelContext.delete(watch)
                dismiss()
            }
        }
    }

    private var overviewSection: some View {
        Section {
            LabeledContent("Brand", value: watch.brand)
            LabeledContent("Model", value: watch.model)
            if let referenceNumber = watch.referenceNumber, !referenceNumber.isEmpty {
                LabeledContent("Reference Number", value: referenceNumber)
            }
            if let serialNumber = watch.serialNumber, !serialNumber.isEmpty {
                LabeledContent("Serial Number", value: serialNumber)
            }
            if !watch.complications.isEmpty {
                LabeledContent("Complications", value: watch.complications.joined(separator: ", "))
            }
            LabeledContent("Case Diameter", value: "\(watch.caseDiameterMM.formatted()) mm")
            LabeledContent("Lug-to-Lug", value: "\(watch.lugToLugMM.formatted()) mm")
            LabeledContent("Lug Width", value: "\(watch.lugWidthMM.formatted()) mm")
            LabeledContent("Acquired", value: watch.acquisitionDate.formatted(date: .abbreviated, time: .omitted))
            if let purchasePrice = watch.purchasePrice {
                LabeledContent("Purchase Price", value: purchasePrice.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
            }
        } header: {
            SectionHeader("Overview")
        }
    }

    /// Hidden entirely (not just an empty Section) when nothing's set — unlike `AddWatchView`,
    /// which always shows these fields ready for entry, the read-only Workbench shouldn't show
    /// an empty "Specifications" card for a watch nobody's added detail to yet.
    @ViewBuilder
    private var specificationsSection: some View {
        if watch.caliber?.isEmpty == false || watch.caseMaterial?.isEmpty == false
            || watch.dialColor?.isEmpty == false || watch.waterResistanceMeters != nil {
            Section {
                if let caliber = watch.caliber, !caliber.isEmpty {
                    LabeledContent("Caliber", value: caliber)
                }
                if let caseMaterial = watch.caseMaterial, !caseMaterial.isEmpty {
                    LabeledContent("Case Material", value: caseMaterial)
                }
                if let dialColor = watch.dialColor, !dialColor.isEmpty {
                    LabeledContent("Dial Color", value: dialColor)
                }
                if let waterResistanceMeters = watch.waterResistanceMeters {
                    LabeledContent("Water Resistance", value: "\(waterResistanceMeters)m")
                }
            } header: {
                SectionHeader("Specifications")
            }
        }
    }

    @ViewBuilder
    private var conditionAndDocumentationSection: some View {
        if watch.condition != nil || watch.boxAndPapersStatus != nil || watch.warrantyExpirationDate != nil
            || watch.insuredValue != nil || watch.appraisalDate != nil {
            Section {
                if let condition = watch.condition {
                    LabeledContent("Condition", value: condition.rawValue)
                }
                if let boxAndPapersStatus = watch.boxAndPapersStatus {
                    LabeledContent("Box & Papers", value: boxAndPapersStatus.rawValue)
                }
                if let warrantyExpirationDate = watch.warrantyExpirationDate {
                    LabeledContent("Warranty Expires", value: warrantyExpirationDate.formatted(date: .abbreviated, time: .omitted))
                }
                if let insuredValue = watch.insuredValue {
                    LabeledContent("Insured Value", value: insuredValue.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
                }
                if let appraisalDate = watch.appraisalDate {
                    LabeledContent("Appraised", value: appraisalDate.formatted(date: .abbreviated, time: .omitted))
                }
            } header: {
                SectionHeader("Condition & Documentation")
            }
        }
    }

    /// Per-watch reminder controls — enable/disable each reminder type and, for Service Due,
    /// override the interval — placed right after Overview so they're the first thing visible
    /// on the Workbench, per the user's request to make reminders "easy to identify" rather than
    /// buried. `SettingsView`'s "Reminders" section still holds the app-wide master switches;
    /// those are an AND gate over these per-watch settings, not a fallback — see
    /// `NotificationManager`'s doc comment. Each binding's `set` reschedules that watch's
    /// notification immediately, the same direct-call pattern `logWindNow()`/`logWearToday()`
    /// already use, rather than adding more `.onChange` modifiers (which is what pushed
    /// `SettingsView.body` over the type checker's limit when this was built there).
    @ViewBuilder
    private var remindersSection: some View {
        if isUnlocked {
            Section {
                Toggle("Service Due Reminder", isOn: serviceDueReminderEnabledBinding)
                    .disabled(!isServiceDueReminderEnabledGlobally)
                Picker("Service Interval", selection: serviceIntervalYearsBinding) {
                    ForEach(1...10, id: \.self) { years in
                        Text("\(years) Year\(years == 1 ? "" : "s")").tag(years)
                    }
                }
                .disabled(!isServiceDueReminderEnabledGlobally)
                if watch.movementType == .manual || watch.movementType == .automatic {
                    Toggle("Wind Reminder", isOn: windReminderEnabledBinding)
                        .disabled(!isWindReminderEnabledGlobally)
                }
            } header: {
                SectionHeader("Reminders")
            } footer: {
                // Only mention whichever master switch is actually off, rather than a generic
                // reminder every time — the greyed-out controls above already show which one.
                if !isServiceDueReminderEnabledGlobally && !isWindReminderEnabledGlobally {
                    Text("Service Due and Wind Reminders are both turned off in Settings, which overrides this watch's settings. Turn them back on in Settings to restore this watch's own choices.")
                } else if !isServiceDueReminderEnabledGlobally {
                    Text("Service Due Reminders are turned off in Settings, which overrides this watch's setting. Turn it back on in Settings to restore this watch's own choice.")
                } else if !isWindReminderEnabledGlobally {
                    Text("Wind Reminders are turned off in Settings, which overrides this watch's setting. Turn it back on in Settings to restore this watch's own choice.")
                }
            }
        } else {
            Section {
                Label("Reminders are a Full Version Feature", systemImage: "lock")
                    .foregroundStyle(.secondary)
            } header: {
                SectionHeader("Reminders")
            } footer: {
                Text("Unlock in Settings to get notified when this watch is due for service or needs winding.")
            }
        }
    }

    private var serviceDueReminderEnabledBinding: Binding<Bool> {
        Binding(
            get: { watch.isServiceDueReminderEnabled ?? true },
            set: { newValue in
                watch.isServiceDueReminderEnabled = newValue
                NotificationManager.scheduleServiceDueReminder(for: watch, isUnlocked: isUnlocked)
            }
        )
    }

    private var serviceIntervalYearsBinding: Binding<Int> {
        Binding(
            get: {
                watch.serviceIntervalYears
                    ?? UserDefaults.standard.object(forKey: NotificationManager.serviceIntervalYearsKey) as? Int
                    ?? NotificationManager.defaultServiceIntervalYears
            },
            set: { newValue in
                watch.serviceIntervalYears = newValue
                NotificationManager.scheduleServiceDueReminder(for: watch, isUnlocked: isUnlocked)
            }
        )
    }

    private var windReminderEnabledBinding: Binding<Bool> {
        Binding(
            get: { watch.isWindReminderEnabled ?? true },
            set: { newValue in
                watch.isWindReminderEnabled = newValue
                NotificationManager.scheduleWindReminder(for: watch, isUnlocked: isUnlocked)
            }
        )
    }

    private var strapsSection: some View {
        Section {
            if let attached = watch.attachedStrap {
                LabeledContent("Attached", value: attached.summary)
                if let notes = attached.notes, !notes.isEmpty {
                    LabeledContent("Notes", value: notes)
                }
                Button("Edit Strap…") { editingStrap = attached }
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
                        Text(pickerLabel(for: strap)).tag(Strap?.some(strap))
                    }
                }
            }

            Button("Add New Strap…") { isAddingStrap = true }
        } header: {
            SectionHeader("Straps")
        }
    }

    /// Flags straps already attached to a different watch so picking them here doesn't
    /// silently detach them from that other watch without warning.
    private func pickerLabel(for strap: Strap) -> String {
        if let attachedWatch = strap.attachedWatch, attachedWatch !== watch {
            return "\(strap.summary) — attached to \(attachedWatch.brand) \(attachedWatch.model)"
        }
        return strap.summary
    }

    /// Tracks a watch currently checked in at a service center — distinct from Service History,
    /// which logs *completed* work. "Mark Picked Up" clears this state and opens Log Service
    /// directly, since picking a watch up from maintenance is usually the moment to record what
    /// was actually done — the same reasoning `logWindNow()`/`logWearToday()` use for
    /// immediately rescheduling after a state change, applied to a UI hand-off instead.
    private var maintenanceSection: some View {
        Section {
            if watch.isOutForMaintenance {
                if let dropOffDate = watch.maintenanceDropOffDate {
                    LabeledContent("Dropped Off", value: dropOffDate.formatted(date: .abbreviated, time: .omitted))
                }
                if let expectedPickupDate = watch.maintenanceExpectedPickupDate {
                    LabeledContent("Expected Pickup", value: expectedPickupDate.formatted(date: .abbreviated, time: .omitted))
                }
                if let notes = watch.maintenanceNotes, !notes.isEmpty {
                    LabeledContent("Notes", value: notes)
                }
                Button("Mark Picked Up") { markPickedUp() }
            } else {
                Text("Not currently out for maintenance.")
                    .foregroundStyle(.secondary)
                Button("Drop Off for Maintenance…") { isDroppingOffForMaintenance = true }
            }
        } header: {
            SectionHeader("Maintenance")
        } footer: {
            Text("Tracks a watch currently checked in at a service center. Marking it picked up clears this and opens Log Service below, so you can record what was actually done.")
        }
    }

    private func markPickedUp() {
        watch.maintenanceDropOffDate = nil
        watch.maintenanceExpectedPickupDate = nil
        watch.maintenanceNotes = nil
        NotificationManager.cancelPickupReminder(for: watch)
        isLoggingService = true
    }

    private var serviceHistorySection: some View {
        Section {
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
            .onDelete(perform: deleteServiceRecords)

            Button("Log Service…") { isLoggingService = true }
        } header: {
            SectionHeader("Service History")
        }
    }

    private func deleteServiceRecords(at offsets: IndexSet) {
        let sorted = watch.serviceRecords.sorted(by: { $0.datePerformed > $1.datePerformed })
        for index in offsets {
            modelContext.delete(sorted[index])
        }
        // Deleting a record can change lastServiceDate/serviceDueDate, same reasoning
        // AddServiceRecordView's save() already reschedules after logging one.
        NotificationManager.scheduleServiceDueReminder(for: watch, isUnlocked: isUnlocked)
    }

    private var wearLogSection: some View {
        Section {
            Button("Log Today") { logWearToday() }

            ForEach(watch.wearLogs.sorted(by: { $0.dateWorn > $1.dateWorn })) { entry in
                VStack(alignment: .leading) {
                    Text(entry.dateWorn.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                    if let notes = entry.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: deleteWearLogs)
        } header: {
            SectionHeader("Wear Log")
        }
    }

    private func logWearToday() {
        let entry = WearLog(watch: watch)
        modelContext.insert(entry)
        // Wearing an automatic also recharges its mainspring (see Watch.lastPoweredDate), so
        // this can push powerReserveExpiresAt out; a no-op reschedule for manual/quartz watches.
        NotificationManager.scheduleWindReminder(for: watch, isUnlocked: isUnlocked)
    }

    private func deleteWearLogs(at offsets: IndexSet) {
        let sorted = watch.wearLogs.sorted(by: { $0.dateWorn > $1.dateWorn })
        for index in offsets {
            modelContext.delete(sorted[index])
        }
        // Same reasoning as logWearToday() — an automatic's lastPoweredDate can depend on wearLogs.
        NotificationManager.scheduleWindReminder(for: watch, isUnlocked: isUnlocked)
    }

    @ViewBuilder
    private var powerReserveSection: some View {
        if watch.movementType == .manual || watch.movementType == .automatic {
            Section {
                Button("Wind Watch") { logWindNow() }

                powerReserveStatus

                ForEach(watch.windLogs.sorted(by: { $0.dateWound > $1.dateWound })) { entry in
                    Text(entry.dateWound.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .onDelete(perform: deleteWindLogs)
            } header: {
                SectionHeader("Power Reserve")
            }
        }
    }

    private func deleteWindLogs(at offsets: IndexSet) {
        let sorted = watch.windLogs.sorted(by: { $0.dateWound > $1.dateWound })
        for index in offsets {
            modelContext.delete(sorted[index])
        }
        // Same reasoning as logWindNow() — deleting a wind can change lastPoweredDate/powerReserveExpiresAt.
        NotificationManager.scheduleWindReminder(for: watch, isUnlocked: isUnlocked)
    }

    @ViewBuilder
    private var powerReserveStatus: some View {
        if watch.powerReserveHours == nil {
            Text("Set a power reserve in Edit Watch to track when this watch runs down.")
                .foregroundStyle(.secondary)
        } else if let expiresAt = watch.powerReserveExpiresAt {
            if watch.isPowerReserveDepleted {
                Text("Power reserve ran out \(expiresAt.formatted(.relative(presentation: .named)))")
                    .foregroundStyle(.orange)
            } else {
                Text("Reserve runs out \(expiresAt.formatted(.relative(presentation: .named)))")
                    .foregroundStyle(.secondary)
            }
        } else {
            Text(watch.movementType == .automatic
                 ? "Log a wind or wear it to start tracking power reserve."
                 : "Log a wind to start tracking power reserve.")
                .foregroundStyle(.secondary)
        }
    }

    private func logWindNow() {
        let entry = WindLog(watch: watch)
        modelContext.insert(entry)
        NotificationManager.scheduleWindReminder(for: watch, isUnlocked: isUnlocked)
    }

    private var provenanceSection: some View {
        Section {
            ForEach(watch.provenanceDocs.sorted(by: { $0.dateAdded > $1.dateAdded })) { doc in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(doc.docType.rawValue)
                            .font(.headline)
                        if let fileName = doc.fileName {
                            Text(fileName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(doc.dateAdded.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete(perform: deleteProvenanceDocs)

            Button("Add Document…") { isAddingProvenanceDoc = true }
        } header: {
            SectionHeader("Provenance")
        }
    }

    private func deleteProvenanceDocs(at offsets: IndexSet) {
        let sorted = watch.provenanceDocs.sorted(by: { $0.dateAdded > $1.dateAdded })
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }

    private var fitPreviewSection: some View {
        Section {
            if let profile = userProfiles.first {
                FitDiagramView(lugToLugMM: watch.lugToLugMM, wristTopWidthCM: profile.wristTopWidthCM)
            } else {
                Text("Add your wrist measurements in Settings to preview fit.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            SectionHeader("Fit Preview")
        }
    }
}

private struct AddStrapView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let watch: Watch
    private let strapToEdit: Strap?

    @State private var name: String
    @State private var material: String
    @State private var widthMM: Double?
    @State private var lengthMM: Double?
    @State private var notes: String
    @State private var isConfirmingDelete = false

    init(watch: Watch, strapToEdit: Strap? = nil) {
        self.watch = watch
        self.strapToEdit = strapToEdit
        _name = State(initialValue: strapToEdit?.name ?? "")
        _material = State(initialValue: strapToEdit?.material ?? "")
        _widthMM = State(initialValue: strapToEdit?.widthMM)
        _lengthMM = State(initialValue: strapToEdit?.lengthMM)
        _notes = State(initialValue: strapToEdit?.notes ?? "")
    }

    private var canSave: Bool {
        !material.trimmingCharacters(in: .whitespaces).isEmpty && (widthMM ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Material", text: $material)
                    LabeledContent("Width") {
                        HStack(spacing: 4) {
                            TextField("0", value: $widthMM, format: .number)
                                .multilineTextAlignment(.trailing)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .frame(maxWidth: 80)
                            Text("mm")
                                .foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Length") {
                        HStack(spacing: 4) {
                            TextField("0", value: $lengthMM, format: .number)
                                .multilineTextAlignment(.trailing)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .frame(maxWidth: 80)
                            Text("mm")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    SectionHeader("Strap")
                }
                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                } header: {
                    SectionHeader("Notes")
                }
                if strapToEdit != nil {
                    Section {
                        Button("Delete Strap", role: .destructive) {
                            isConfirmingDelete = true
                        }
                    }
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .navigationTitle(strapToEdit == nil ? "Add Strap" : "Edit Strap")
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
            .confirmationDialog(
                "Delete this strap?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive, action: deleteStrap)
            } message: {
                Text("This removes the strap entirely, not just from this watch.")
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, idealWidth: 420, minHeight: 360, idealHeight: 400)
        #endif
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        if let strapToEdit {
            strapToEdit.name = trimmedName.isEmpty ? nil : trimmedName
            strapToEdit.material = material.trimmingCharacters(in: .whitespaces)
            strapToEdit.widthMM = widthMM ?? 0
            strapToEdit.lengthMM = lengthMM
            strapToEdit.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        } else {
            let strap = Strap(
                name: trimmedName.isEmpty ? nil : trimmedName,
                material: material.trimmingCharacters(in: .whitespaces),
                widthMM: widthMM ?? 0,
                lengthMM: lengthMM,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            modelContext.insert(strap)
            watch.attachedStrap = strap
        }
        dismiss()
    }

    private func deleteStrap() {
        guard let strapToEdit else { return }
        // Strap.attachedWatch has no explicit deleteRule, which defaults to .nullify — deleting
        // the strap directly is safe and automatically clears watch.attachedStrap if this was it.
        modelContext.delete(strapToEdit)
        dismiss()
    }
}

private struct AddServiceRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var entitlements: [Entitlements]

    let watch: Watch

    @State private var datePerformed = Date()
    @State private var serviceType = ""
    @State private var accuracyDeltaSPD: Double?

    private var canSave: Bool {
        !serviceType.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isUnlocked: Bool {
        entitlements.first?.isLifetimeUnlocked ?? false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date Performed", selection: $datePerformed, displayedComponents: .date)
                    TextField("Service Type", text: $serviceType)
                } header: {
                    SectionHeader("Service")
                }
                Section {
                    LabeledContent("Accuracy Delta") {
                        HStack(spacing: 4) {
                            TextField("0", value: $accuracyDeltaSPD, format: .number)
                                .multilineTextAlignment(.trailing)
                                #if os(iOS)
                                .keyboardType(.numbersAndPunctuation)
                                #endif
                                .frame(maxWidth: 80)
                            Text("sec/day")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    SectionHeader("Accuracy")
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .navigationTitle("Log Service")
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
        }
        #if os(macOS)
        .frame(minWidth: 380, idealWidth: 420, minHeight: 280, idealHeight: 320)
        #endif
    }

    private func save() {
        let record = ServiceRecord(
            datePerformed: datePerformed,
            serviceType: serviceType.trimmingCharacters(in: .whitespaces),
            accuracyDeltaSPD: accuracyDeltaSPD ?? 0,
            watch: watch
        )
        modelContext.insert(record)
        NotificationManager.scheduleServiceDueReminder(for: watch, isUnlocked: isUnlocked)
        dismiss()
    }
}

private struct DropOffForMaintenanceView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var entitlements: [Entitlements]

    let watch: Watch

    @State private var dropOffDate = Date()
    @State private var hasExpectedPickupDate = false
    @State private var expectedPickupDate = Date()
    @State private var notes = ""

    private var isUnlocked: Bool {
        entitlements.first?.isLifetimeUnlocked ?? false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Dropped Off", selection: $dropOffDate, displayedComponents: .date)
                    Toggle("Expected Pickup Date", isOn: $hasExpectedPickupDate)
                    if hasExpectedPickupDate {
                        DatePicker("Expected Pickup", selection: $expectedPickupDate, displayedComponents: .date)
                    }
                } header: {
                    SectionHeader("Maintenance")
                }
                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                } header: {
                    SectionHeader("Notes")
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .navigationTitle("Drop Off for Maintenance")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, idealWidth: 420, minHeight: 320, idealHeight: 360)
        #endif
    }

    private func save() {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        watch.maintenanceDropOffDate = dropOffDate
        watch.maintenanceExpectedPickupDate = hasExpectedPickupDate ? expectedPickupDate : nil
        watch.maintenanceNotes = trimmedNotes.isEmpty ? nil : trimmedNotes
        NotificationManager.schedulePickupReminder(for: watch, isUnlocked: isUnlocked)
        dismiss()
    }
}

private struct AddProvenanceDocView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let watch: Watch

    @State private var docType: ProvenanceDocType = .receipt
    @State private var isImportingFile = false
    @State private var fileData: Data?
    @State private var fileName: String?

    private var canSave: Bool {
        fileData != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $docType) {
                        ForEach(ProvenanceDocType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    Button {
                        isImportingFile = true
                    } label: {
                        if let fileName {
                            Label(fileName, systemImage: "doc.fill")
                        } else {
                            Label("Choose File…", systemImage: "doc.badge.plus")
                        }
                    }
                } header: {
                    SectionHeader("Document")
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .navigationTitle("Add Document")
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
            .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.pdf, .image]) { result in
                guard let url = try? result.get() else { return }
                let didAccess = url.startAccessingSecurityScopedResource()
                defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                fileData = try? Data(contentsOf: url)
                fileName = url.lastPathComponent
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, idealWidth: 420, minHeight: 260, idealHeight: 300)
        #endif
    }

    private func save() {
        guard let fileData else { return }
        let doc = ProvenanceDoc(docType: docType, fileData: fileData, fileName: fileName, watch: watch)
        modelContext.insert(doc)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        WatchDetailView(watch: Watch(brand: "Rolex", model: "Explorer", caseDiameterMM: 36, lugToLugMM: 44, lugWidthMM: 19))
    }
    .modelContainer(for: [Watch.self, Entitlements.self], inMemory: true)
}
