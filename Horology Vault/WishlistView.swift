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
                            WishlistRow(item: item)
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
            Toggle(isOn: .constant(false)) {
                Label("Price Alert", systemImage: "bell")
                    .font(.footnote)
            }
            .disabled(true)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct AddWishlistItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var brand = ""
    @State private var model = ""
    @State private var targetPrice: Double?
    @State private var notes = ""

    private var canSave: Bool {
        !brand.trimmingCharacters(in: .whitespaces).isEmpty
            && !model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Watch") {
                    TextField("Brand", text: $brand)
                    TextField("Model", text: $model)
                }
                Section("Target Price") {
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
                }
                Section("Notes") {
                    TextField("Reference, dream spec, where to find it…", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            #if os(macOS)
            // The default macOS Form style left-aligns its sections in a narrow
            // column instead of centering them like System Settings; .grouped
            // matches that centered, card-style layout.
            .formStyle(.grouped)
            #endif
            .navigationTitle("Add to Wishlist")
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
    }

    private func save() {
        let item = WishlistItem(
            brand: brand.trimmingCharacters(in: .whitespaces),
            model: model.trimmingCharacters(in: .whitespaces),
            targetPrice: targetPrice ?? 0,
            notes: notes.trimmingCharacters(in: .whitespaces)
        )
        modelContext.insert(item)
        dismiss()
    }
}

#Preview {
    WishlistView()
        .modelContainer(for: WishlistItem.self, inMemory: true)
}
