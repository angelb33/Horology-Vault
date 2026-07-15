//
//  ServiceCentersView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/14/26.
//

import SwiftUI
import SwiftData

/// An `OfficialServiceDirectory` entry merged with any user `ServiceContactOverride` for the
/// same brand — what the UI actually displays and edits.
private struct EffectiveOfficialContact: Identifiable {
    let base: OfficialServiceContact
    let override: ServiceContactOverride?

    var id: String { base.brand }
    var brand: String { base.brand }
    var name: String { override?.name ?? base.name }
    var website: String { override?.website ?? base.website }
    var notes: String { override?.notes ?? base.notes }
    var phone: String? { override?.phone }
    var address: String? { override?.address }
    var secondaryWebsite: String? { override?.secondaryWebsite }
    var isOverridden: Bool { override != nil }
}

struct ServiceCentersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomServiceCenter.name) private var customCenters: [CustomServiceCenter]
    @Query private var overrides: [ServiceContactOverride]

    @State private var searchText = ""
    @State private var isAddingCenter = false
    @State private var editingCustomCenter: CustomServiceCenter?
    @State private var editingOfficialContact: EffectiveOfficialContact?
    @State private var isManufacturerSectionExpanded = true
    @State private var isCustomSectionExpanded = true

    private var effectiveOfficialContacts: [EffectiveOfficialContact] {
        let overridesByBrand = Dictionary(uniqueKeysWithValues: overrides.map { ($0.brand, $0) })
        return OfficialServiceDirectory.contacts.map {
            EffectiveOfficialContact(base: $0, override: overridesByBrand[$0.brand])
        }
    }

    private var filteredOfficialContacts: [EffectiveOfficialContact] {
        guard !searchText.isEmpty else { return effectiveOfficialContacts }
        return effectiveOfficialContacts.filter {
            $0.brand.localizedCaseInsensitiveContains(searchText) || $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredCustomCenters: [CustomServiceCenter] {
        guard !searchText.isEmpty else { return customCenters }
        return customCenters.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) || ($0.brand?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !filteredOfficialContacts.isEmpty {
                    DisclosureGroup(isExpanded: $isManufacturerSectionExpanded) {
                        ForEach(filteredOfficialContacts) { contact in
                            OfficialContactRow(
                                contact: contact,
                                onEdit: { editingOfficialContact = contact },
                                onReset: { resetOfficialContact(contact) }
                            )
                        }
                    } label: {
                        SectionHeader("Manufacturer Support (\(filteredOfficialContacts.count))")
                    }
                }

                DisclosureGroup(isExpanded: $isCustomSectionExpanded) {
                    if filteredCustomCenters.isEmpty {
                        Text(customCenters.isEmpty ? "No custom service centers added yet." : "No matches.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredCustomCenters) { center in
                            CustomCenterRow(center: center, onEdit: { editingCustomCenter = center })
                        }
                        .onDelete(perform: deleteCustomCenters)
                    }
                } label: {
                    SectionHeader("My Service Centers (\(filteredCustomCenters.count))")
                }
            }
            .searchable(text: $searchText, prompt: "Search by brand or name")
            .onChange(of: searchText) { _, newValue in
                guard !newValue.isEmpty else { return }
                isManufacturerSectionExpanded = true
                isCustomSectionExpanded = true
            }
            .navigationTitle("Service Centers")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingCenter = true
                    } label: {
                        Label("Add Service Center", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingCenter) {
                AddServiceCenterView()
            }
            .sheet(item: $editingCustomCenter) { center in
                AddServiceCenterView(centerToEdit: center)
            }
            .sheet(item: $editingOfficialContact) { contact in
                EditOfficialContactView(contact: contact)
            }
        }
    }

    private func deleteCustomCenters(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredCustomCenters[index])
        }
    }

    private func resetOfficialContact(_ contact: EffectiveOfficialContact) {
        guard let override = contact.override else { return }
        modelContext.delete(override)
    }
}

private struct OfficialContactRow: View {
    let contact: EffectiveOfficialContact
    let onEdit: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(contact.name)
                        .font(.headline)
                    if contact.isOverridden {
                        Text("Edited")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.secondary.opacity(0.15), in: Capsule())
                    }
                }
                Text(contact.brand)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(contact.website)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let secondaryWebsite = contact.secondaryWebsite, !secondaryWebsite.isEmpty {
                    Text(secondaryWebsite)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let phone = contact.phone, !phone.isEmpty {
                    Text(phone)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let address = contact.address, !address.isEmpty {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(contact.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let url = URL(string: "https://\(contact.website)") {
                Link(destination: url) {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .contextMenu {
            Button("Edit", systemImage: "pencil", action: onEdit)
            if contact.isOverridden {
                Button("Reset to Default", systemImage: "arrow.uturn.backward", role: .destructive, action: onReset)
            }
        }
    }
}

private struct CustomCenterRow: View {
    let center: CustomServiceCenter
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(center.name)
                .font(.headline)
            if let brand = center.brand, !brand.isEmpty {
                Text(brand)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let phone = center.phone, !phone.isEmpty {
                Text(phone)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let website = center.website, !website.isEmpty, let url = URL(string: website.hasPrefix("http") ? website : "https://\(website)") {
                Link(website, destination: url)
                    .font(.caption)
            }
            if let secondaryWebsite = center.secondaryWebsite, !secondaryWebsite.isEmpty, let url = URL(string: secondaryWebsite.hasPrefix("http") ? secondaryWebsite : "https://\(secondaryWebsite)") {
                Link(secondaryWebsite, destination: url)
                    .font(.caption)
            }
            if let address = center.address, !address.isEmpty {
                Text(address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let notes = center.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .contextMenu {
            Button("Edit", systemImage: "pencil", action: onEdit)
        }
    }
}

private struct EditOfficialContactView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    fileprivate let contact: EffectiveOfficialContact

    @State private var name: String
    @State private var website: String
    @State private var notes: String
    @State private var phone: String
    @State private var address: String
    @State private var secondaryWebsite: String

    fileprivate init(contact: EffectiveOfficialContact) {
        self.contact = contact
        _name = State(initialValue: contact.name)
        _website = State(initialValue: contact.website)
        _notes = State(initialValue: contact.notes)
        _phone = State(initialValue: contact.phone ?? "")
        _address = State(initialValue: contact.address ?? "")
        _secondaryWebsite = State(initialValue: contact.secondaryWebsite ?? "")
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !website.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Website", text: $website)
                        #if os(iOS)
                        .keyboardType(.URL)
                        #endif
                    TextField("Second Website (optional)", text: $secondaryWebsite)
                        #if os(iOS)
                        .keyboardType(.URL)
                        #endif
                    TextField("Phone (optional)", text: $phone)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif
                    TextField("Address (optional)", text: $address, axis: .vertical)
                        .lineLimit(2, reservesSpace: true)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                } header: {
                    SectionHeader(contact.brand)
                }
                if contact.isOverridden {
                    Section {
                        Button("Reset to Default", role: .destructive, action: resetToDefault)
                    } footer: {
                        Text("Removes your edits and restores the bundled default for this brand.")
                    }
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .navigationTitle("Edit Contact")
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
        .frame(minWidth: 380, idealWidth: 420, minHeight: 320, idealHeight: 360)
        #endif
    }

    private func save() {
        func trimmedOrNil(_ text: String) -> String? {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedWebsite = website.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        let trimmedPhone = trimmedOrNil(phone)
        let trimmedAddress = trimmedOrNil(address)
        let trimmedSecondaryWebsite = trimmedOrNil(secondaryWebsite)

        if let existingOverride = contact.override {
            existingOverride.name = trimmedName
            existingOverride.website = trimmedWebsite
            existingOverride.notes = trimmedNotes
            existingOverride.phone = trimmedPhone
            existingOverride.address = trimmedAddress
            existingOverride.secondaryWebsite = trimmedSecondaryWebsite
        } else {
            modelContext.insert(ServiceContactOverride(
                brand: contact.brand,
                name: trimmedName,
                website: trimmedWebsite,
                notes: trimmedNotes,
                phone: trimmedPhone,
                address: trimmedAddress,
                secondaryWebsite: trimmedSecondaryWebsite
            ))
        }
        dismiss()
    }

    private func resetToDefault() {
        if let existingOverride = contact.override {
            modelContext.delete(existingOverride)
        }
        dismiss()
    }
}

private struct AddServiceCenterView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let centerToEdit: CustomServiceCenter?

    @State private var name: String
    @State private var brand: String
    @State private var phone: String
    @State private var website: String
    @State private var secondaryWebsite: String
    @State private var address: String
    @State private var notes: String

    init(centerToEdit: CustomServiceCenter? = nil) {
        self.centerToEdit = centerToEdit
        _name = State(initialValue: centerToEdit?.name ?? "")
        _brand = State(initialValue: centerToEdit?.brand ?? "")
        _phone = State(initialValue: centerToEdit?.phone ?? "")
        _website = State(initialValue: centerToEdit?.website ?? "")
        _secondaryWebsite = State(initialValue: centerToEdit?.secondaryWebsite ?? "")
        _address = State(initialValue: centerToEdit?.address ?? "")
        _notes = State(initialValue: centerToEdit?.notes ?? "")
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Brand (optional)", text: $brand)
                    TextField("Phone", text: $phone)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif
                    TextField("Website", text: $website)
                        #if os(iOS)
                        .keyboardType(.URL)
                        #endif
                    TextField("Second Website (optional)", text: $secondaryWebsite)
                        #if os(iOS)
                        .keyboardType(.URL)
                        #endif
                    TextField("Address", text: $address, axis: .vertical)
                        .lineLimit(2, reservesSpace: true)
                } header: {
                    SectionHeader("Service Center")
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
            .navigationTitle(centerToEdit == nil ? "Add Service Center" : "Edit Service Center")
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
        .frame(minWidth: 380, idealWidth: 420, minHeight: 420, idealHeight: 460)
        #endif
    }

    private func save() {
        func trimmedOrNil(_ text: String) -> String? {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }

        if let centerToEdit {
            centerToEdit.name = name.trimmingCharacters(in: .whitespaces)
            centerToEdit.brand = trimmedOrNil(brand)
            centerToEdit.phone = trimmedOrNil(phone)
            centerToEdit.website = trimmedOrNil(website)
            centerToEdit.secondaryWebsite = trimmedOrNil(secondaryWebsite)
            centerToEdit.address = trimmedOrNil(address)
            centerToEdit.notes = trimmedOrNil(notes)
        } else {
            let center = CustomServiceCenter(
                name: name.trimmingCharacters(in: .whitespaces),
                brand: trimmedOrNil(brand),
                phone: trimmedOrNil(phone),
                website: trimmedOrNil(website),
                secondaryWebsite: trimmedOrNil(secondaryWebsite),
                address: trimmedOrNil(address),
                notes: trimmedOrNil(notes)
            )
            modelContext.insert(center)
        }
        dismiss()
    }
}

#Preview {
    ServiceCentersView()
        .modelContainer(for: CustomServiceCenter.self, inMemory: true)
}
