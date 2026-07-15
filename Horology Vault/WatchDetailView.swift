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

    private var compatibleStraps: [Strap] {
        allStraps.filter { $0.widthMM == watch.lugWidthMM }
    }

    @State private var isEditing = false
    @State private var isAddingStrap = false
    @State private var isLoggingService = false
    @State private var isAddingProvenanceDoc = false
    @State private var isConfirmingDelete = false

    var body: some View {
        Form {
            overviewSection
            strapsSection
            serviceHistorySection
            wearLogSection
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
        .sheet(isPresented: $isLoggingService) {
            AddServiceRecordView(watch: watch)
        }
        .sheet(isPresented: $isAddingProvenanceDoc) {
            AddProvenanceDocView(watch: watch)
        }
        .confirmationDialog(
            "Delete \(watch.brand) \(watch.model)?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                NotificationManager.cancelServiceDueReminder(for: watch)
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

    private var strapsSection: some View {
        Section {
            if let attached = watch.attachedStrap {
                LabeledContent("Attached", value: attached.summary)
                if let notes = attached.notes, !notes.isEmpty {
                    LabeledContent("Notes", value: notes)
                }
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

            Button("Log Service…") { isLoggingService = true }
        } header: {
            SectionHeader("Service History")
        }
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
        } header: {
            SectionHeader("Wear Log")
        }
    }

    private func logWearToday() {
        let entry = WearLog(watch: watch)
        modelContext.insert(entry)
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

    @State private var name = ""
    @State private var material = ""
    @State private var widthMM: Double?
    @State private var lengthMM: Double?
    @State private var notes = ""

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
            }
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .navigationTitle("Add Strap")
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
        .frame(minWidth: 380, idealWidth: 420, minHeight: 360, idealHeight: 400)
        #endif
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        let strap = Strap(
            name: trimmedName.isEmpty ? nil : trimmedName,
            material: material.trimmingCharacters(in: .whitespaces),
            widthMM: widthMM ?? 0,
            lengthMM: lengthMM,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )
        modelContext.insert(strap)
        watch.attachedStrap = strap
        dismiss()
    }
}

private struct AddServiceRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let watch: Watch

    @State private var datePerformed = Date()
    @State private var serviceType = ""
    @State private var accuracyDeltaSPD: Double?

    private var canSave: Bool {
        !serviceType.trimmingCharacters(in: .whitespaces).isEmpty
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
        NotificationManager.scheduleServiceDueReminder(for: watch)
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
    .modelContainer(for: Watch.self, inMemory: true)
}
