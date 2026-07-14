//
//  ServiceCentersView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/14/26.
//

import SwiftUI
import SwiftData

struct ServiceCentersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomServiceCenter.name) private var customCenters: [CustomServiceCenter]

    @State private var searchText = ""
    @State private var isAddingCenter = false

    private var filteredOfficialContacts: [OfficialServiceContact] {
        guard !searchText.isEmpty else { return OfficialServiceDirectory.contacts }
        return OfficialServiceDirectory.contacts.filter {
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
                    Section("Manufacturer Support") {
                        ForEach(filteredOfficialContacts) { contact in
                            OfficialContactRow(contact: contact)
                        }
                    }
                }

                Section("My Service Centers") {
                    if filteredCustomCenters.isEmpty {
                        Text(customCenters.isEmpty ? "No custom service centers added yet." : "No matches.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredCustomCenters) { center in
                            CustomCenterRow(center: center)
                        }
                        .onDelete(perform: deleteCustomCenters)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search by brand or name")
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
        }
    }

    private func deleteCustomCenters(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredCustomCenters[index])
        }
    }
}

private struct OfficialContactRow: View {
    let contact: OfficialServiceContact

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(contact.name)
                .font(.headline)
            Text(contact.brand)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let url = URL(string: "https://\(contact.website)") {
                Link(contact.website, destination: url)
                    .font(.caption)
            }
            Text(contact.notes)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct CustomCenterRow: View {
    let center: CustomServiceCenter

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
    }
}

private struct AddServiceCenterView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var phone = ""
    @State private var website = ""
    @State private var address = ""
    @State private var notes = ""

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Service Center") {
                    TextField("Name", text: $name)
                    TextField("Brand (optional)", text: $brand)
                    TextField("Phone", text: $phone)
                    TextField("Website", text: $website)
                        #if os(iOS)
                        .keyboardType(.URL)
                        #endif
                    TextField("Address", text: $address, axis: .vertical)
                        .lineLimit(2, reservesSpace: true)
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .navigationTitle("Add Service Center")
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

        let center = CustomServiceCenter(
            name: name.trimmingCharacters(in: .whitespaces),
            brand: trimmedOrNil(brand),
            phone: trimmedOrNil(phone),
            website: trimmedOrNil(website),
            address: trimmedOrNil(address),
            notes: trimmedOrNil(notes)
        )
        modelContext.insert(center)
        dismiss()
    }
}

#Preview {
    ServiceCentersView()
        .modelContainer(for: CustomServiceCenter.self, inMemory: true)
}
