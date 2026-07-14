//
//  SettingsView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/11/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var csvExportDocument: CSVDocument?
    @State private var isExportingCSV = false
    @State private var isImportingCSV = false

    @State private var backupExportDocument: BackupDocument?
    @State private var isExportingBackup = false
    @State private var isImportingBackup = false

    private enum PassphrasePurpose {
        case creatingBackup
        case restoringBackup(Data)
    }
    @State private var passphrasePurpose: PassphrasePurpose?
    @State private var passphraseInput = ""

    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                wristProfileSection
                dataSection
                purchaseStatusSection
                aboutSection
            }
            #if os(macOS)
            // The default macOS Form style left-aligns its sections in a narrow
            // column instead of centering them like System Settings; .grouped
            // matches that centered, card-style layout.
            .formStyle(.grouped)
            #endif
            .navigationTitle("Settings")
            .onAppear(perform: ensureProfileExists)
            .fileExporter(isPresented: $isExportingCSV, document: csvExportDocument, contentType: .commaSeparatedText, defaultFilename: "HorologyVaultWatches") { result in
                if case .failure(let error) = result {
                    statusMessage = error.localizedDescription
                }
            }
            .fileImporter(isPresented: $isImportingCSV, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                do {
                    let url = try result.get()
                    let didAccess = url.startAccessingSecurityScopedResource()
                    defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                    let text = try String(contentsOf: url, encoding: .utf8)
                    let outcome = try DataBackupManager.importWatchesCSV(text, context: modelContext)
                    statusMessage = "Imported \(outcome.imported) watch(es)"
                        + (outcome.skipped > 0 ? ", skipped \(outcome.skipped) invalid row(s)." : ".")
                } catch {
                    statusMessage = error.localizedDescription
                }
            }
            .fileExporter(isPresented: $isExportingBackup, document: backupExportDocument, contentType: .data, defaultFilename: "HorologyVaultBackup.hvbackup") { result in
                if case .failure(let error) = result {
                    statusMessage = error.localizedDescription
                }
            }
            .fileImporter(isPresented: $isImportingBackup, allowedContentTypes: [.data]) { result in
                do {
                    let url = try result.get()
                    let didAccess = url.startAccessingSecurityScopedResource()
                    defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                    let data = try Data(contentsOf: url)
                    passphrasePurpose = .restoringBackup(data)
                } catch {
                    statusMessage = error.localizedDescription
                }
            }
            .alert(
                passphrasePromptTitle,
                isPresented: Binding(
                    get: { passphrasePurpose != nil },
                    set: { isPresented in if !isPresented { passphrasePurpose = nil; passphraseInput = "" } }
                )
            ) {
                SecureField("Passphrase", text: $passphraseInput)
                Button("Cancel", role: .cancel) { passphrasePurpose = nil; passphraseInput = "" }
                Button(passphraseConfirmLabel, action: confirmPassphrase)
            } message: {
                Text(passphrasePromptMessage)
            }
            .alert("Data", isPresented: Binding(
                get: { statusMessage != nil },
                set: { isPresented in if !isPresented { statusMessage = nil } }
            )) {
                Button("OK") { statusMessage = nil }
            } message: {
                Text(statusMessage ?? "")
            }
        }
    }

    private var passphrasePromptTitle: String {
        switch passphrasePurpose {
        case .creatingBackup: "Set a Backup Passphrase"
        case .restoringBackup: "Enter Backup Passphrase"
        case nil: ""
        }
    }

    private var passphrasePromptMessage: String {
        switch passphrasePurpose {
        case .creatingBackup: "This passphrase encrypts your backup file. You'll need it again to restore it — don't lose it."
        case .restoringBackup: "Enter the passphrase used when this backup was created."
        case nil: ""
        }
    }

    private var passphraseConfirmLabel: String {
        switch passphrasePurpose {
        case .creatingBackup: "Create Backup"
        case .restoringBackup: "Restore"
        case nil: "OK"
        }
    }

    private func confirmPassphrase() {
        guard let purpose = passphrasePurpose else { return }
        let passphrase = passphraseInput
        passphraseInput = ""
        passphrasePurpose = nil

        switch purpose {
        case .creatingBackup:
            do {
                let data = try DataBackupManager.exportEncryptedBackup(context: modelContext, passphrase: passphrase)
                backupExportDocument = BackupDocument(data: data)
                isExportingBackup = true
            } catch {
                statusMessage = error.localizedDescription
            }
        case .restoringBackup(let fileData):
            do {
                let summary = try DataBackupManager.importEncryptedBackup(fileData, passphrase: passphrase, context: modelContext)
                NotificationManager.rescheduleAll(for: (try? modelContext.fetch(FetchDescriptor<Watch>())) ?? [])
                statusMessage = "Restored \(summary.watchesRestored) watch(es), \(summary.strapsRestored) strap(s), \(summary.wishlistItemsRestored) wishlist item(s)"
                    + (summary.profileRestored ? ", and your wrist profile." : ".")
            } catch {
                statusMessage = error.localizedDescription
            }
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
            Button {
                isImportingCSV = true
            } label: {
                Label("Import from CSV", systemImage: "square.and.arrow.down")
            }
            Button {
                do {
                    csvExportDocument = CSVDocument(text: try DataBackupManager.exportWatchesCSV(context: modelContext))
                    isExportingCSV = true
                } catch {
                    statusMessage = error.localizedDescription
                }
            } label: {
                Label("Export to CSV", systemImage: "square.and.arrow.up")
            }
            Button {
                passphrasePurpose = .creatingBackup
            } label: {
                Label("Encrypted Backup", systemImage: "lock.doc")
            }
            Button {
                isImportingBackup = true
            } label: {
                Label("Restore from Backup", systemImage: "arrow.clockwise")
            }
        } header: {
            Text("Data")
        } footer: {
            Text("CSV covers your watch list; the encrypted backup captures your entire collection, including straps, service history, wear log, and provenance documents.")
        }
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

#Preview {
    SettingsView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
