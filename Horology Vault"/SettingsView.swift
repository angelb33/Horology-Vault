//
//  SettingsView.swift
//  Horology Vault"
//
//  Created by Angel Burgos on 7/11/26.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    var body: some View {
        NavigationStack {
            Form {
                wristProfileSection
                dataSection
                purchaseStatusSection
                aboutSection
            }
            .navigationTitle("Settings")
            .onAppear(perform: ensureProfileExists)
        }
    }

    // MARK: Wrist Profile

    @ViewBuilder
    private var wristProfileSection: some View {
        Section {
            if let profile = profiles.first {
                WristMeasurementField(label: "Top Width", unit: "cm", value: bindableTopWidth(profile))
                WristMeasurementField(label: "Side Depth", unit: "cm", value: bindableSideDepth(profile))
            }
        } header: {
            Text("Wrist Profile")
        } footer: {
            Text("Used by the Fit Calculator to compare a watch's lug-to-lug against your wrist.")
        }
    }

    private func bindableTopWidth(_ profile: UserProfile) -> Binding<Double> {
        Binding(get: { profile.wristTopWidthCM }, set: { profile.wristTopWidthCM = $0 })
    }

    private func bindableSideDepth(_ profile: UserProfile) -> Binding<Double> {
        Binding(get: { profile.wristSideDepthCM }, set: { profile.wristSideDepthCM = $0 })
    }

    private func ensureProfileExists() {
        guard profiles.isEmpty else { return }
        modelContext.insert(UserProfile(wristTopWidthCM: 0, wristSideDepthCM: 0))
    }

    // MARK: Data

    private var dataSection: some View {
        Section {
            // Local file I/O — implementations land alongside the CSV/backup work.
            Button {} label: {
                Label("Import from CSV", systemImage: "square.and.arrow.down")
            }
            Button {} label: {
                Label("Export to CSV", systemImage: "square.and.arrow.up")
            }
            Button {} label: {
                Label("Encrypted Backup", systemImage: "lock.doc")
            }
            Button {} label: {
                Label("Restore from Backup", systemImage: "arrow.clockwise")
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Import, export, and encrypted backup are coming soon.")
        }
        .disabled(true)
    }

    // MARK: Purchase Status

    private var purchaseStatusSection: some View {
        Section {
            LabeledContent("Version") {
                // Static until the Entitlements table + PurchaseManager (StoreKit 2) land;
                // this label will then read is_lifetime_unlocked instead of being hardcoded.
                Label("Full Version", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .labelStyle(.titleAndIcon)
            }
            Button("Restore Purchase") {}
                // Wired to PurchaseManager.restore() once StoreKit/Entitlements are added.
                .disabled(true)
        } header: {
            Text("Purchase")
        }
    }

    // MARK: About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("App", value: "Horology Vault")
            LabeledContent("Version", value: appVersionString)
            LabeledContent("Support", value: "angelburgosjr@gmail.com")
        }
    }

    private var appVersionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}

/// Labeled numeric entry with a trailing unit, matching the measurement rows used
/// elsewhere in the app.
private struct WristMeasurementField: View {
    let label: String
    let unit: String
    @Binding var value: Double

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

#Preview {
    SettingsView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
