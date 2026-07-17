//
//  WishlistView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/11/26.
//

import SwiftUI
import SwiftData

struct WishlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\WishlistItem.brand), SortDescriptor(\WishlistItem.model)])
    private var items: [WishlistItem]

    @State private var isAddingItem = false
    @State private var editingItem: WishlistItem?

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Wishlist Items",
                        systemImage: "star",
                        description: Text("Track the watches you're hunting for.")
                    )
                } else {
                    List {
                        ForEach(items) { item in
                            WishlistRow(item: item, onEdit: { editingItem = item })
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Wishlist")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingItem = true
                    } label: {
                        Label("Add to Wishlist", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingItem) {
                AddWishlistItemView()
            }
            .sheet(item: $editingItem) { item in
                AddWishlistItemView(itemToEdit: item)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
}

private struct WishlistRow: View {
    let item: WishlistItem
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.brand)
                        .font(.headline)
                    Text(item.model)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(item.targetPrice, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.callout.weight(.medium))
                    .monospacedDigit()
            }

            if !item.notes.isEmpty {
                Text(item.notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // Price alerts are a V2 (subscription) feature — surfaced here so the row
            // reads complete, but disabled until the backend price-polling ships.
            VStack(alignment: .leading, spacing: 2) {
                Toggle(isOn: .constant(false)) {
                    Label("Price Alert", systemImage: "bell")
                        .font(.footnote)
                }
                .disabled(true)
                Text("Coming in a future update")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .contextMenu {
            Button("Edit", systemImage: "pencil", action: onEdit)
        }
    }
}

private struct AddWishlistItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let itemToEdit: WishlistItem?

    @State private var brand: String
    @State private var model: String
    @State private var targetPrice: Double?
    @State private var notes: String
    @State private var isConfirmingDelete = false

    init(itemToEdit: WishlistItem? = nil) {
        self.itemToEdit = itemToEdit
        _brand = State(initialValue: itemToEdit?.brand ?? "")
        _model = State(initialValue: itemToEdit?.model ?? "")
        _targetPrice = State(initialValue: itemToEdit?.targetPrice)
        _notes = State(initialValue: itemToEdit?.notes ?? "")
    }

    private var canSave: Bool {
        !brand.trimmingCharacters(in: .whitespaces).isEmpty
            && !model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Brand", text: $brand)
                    TextField("Model", text: $model)
                } header: {
                    SectionHeader("Watch")
                }
                Section {
                    HStack {
                        Text("Target Price")
                        Spacer()
                        TextField("0", value: $targetPrice, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .frame(maxWidth: 120)
                    }
                } header: {
                    SectionHeader("Target Price")
                }
                Section {
                    TextField("Reference, dream spec, where to find it…", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                } header: {
                    SectionHeader("Notes")
                }
                if itemToEdit != nil {
                    Section {
                        Button("Delete Wishlist Item", role: .destructive) {
                            isConfirmingDelete = true
                        }
                    }
                }
            }
            #if os(macOS)
            // The default macOS Form style left-aligns its sections in a narrow
            // column instead of centering them like System Settings; .grouped
            // matches that centered, card-style layout.
            .formStyle(.grouped)
            #endif
            .navigationTitle(itemToEdit == nil ? "Add to Wishlist" : "Edit Wishlist Item")
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
                "Delete \(itemToEdit?.brand ?? "") \(itemToEdit?.model ?? "")?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive, action: deleteItem)
            }
        }
    }

    private func save() {
        if let itemToEdit {
            itemToEdit.brand = brand.trimmingCharacters(in: .whitespaces)
            itemToEdit.model = model.trimmingCharacters(in: .whitespaces)
            itemToEdit.targetPrice = targetPrice ?? 0
            itemToEdit.notes = notes.trimmingCharacters(in: .whitespaces)
        } else {
            let item = WishlistItem(
                brand: brand.trimmingCharacters(in: .whitespaces),
                model: model.trimmingCharacters(in: .whitespaces),
                targetPrice: targetPrice ?? 0,
                notes: notes.trimmingCharacters(in: .whitespaces)
            )
            modelContext.insert(item)
        }
        dismiss()
    }

    private func deleteItem() {
        guard let itemToEdit else { return }
        modelContext.delete(itemToEdit)
        dismiss()
    }
}

#Preview {
    WishlistView()
        .modelContainer(for: WishlistItem.self, inMemory: true)
}
