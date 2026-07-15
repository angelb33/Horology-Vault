//
//  SettingsView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/11/26.
//

import SwiftUI
import SwiftData
import StoreKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PurchaseManager.self) private var purchaseManager
    @Query private var profiles: [UserProfile]
    @Query private var entitlements: [Entitlements]

    @AppStorage("colorSchemePreference") private var colorSchemePreference: ColorSchemePreference = .system
    @AppStorage("accentColorOption") private var accentColorOption: AccentColorOption = .blue

    @State private var csvExportDocument: CSVDocument?
    @State private var isExportingCSV = false
    @State private var isImportingCSV = false

    @State private var backupExportDocument: BackupDocument?
    @State private var isExportingBackup = false
    @State private var isImportingBackup = false

    private enum PassphrasePurpose {
        case creatingBackup
        case restoringBackup(Data)
        case settingScheduledBackupPassphrase
    }
    @State private var passphrasePurpose: PassphrasePurpose?
    @State private var passphraseInput = ""

    @State private var statusMessage: String?

    @AppStorage(ScheduledBackupManager.enabledKey) private var isScheduledBackupEnabled = false
    @AppStorage(ScheduledBackupManager.frequencyKey) private var scheduledBackupFrequency: ScheduledBackupManager.BackupFrequency = .weekly
    @AppStorage(ScheduledBackupManager.folderBookmarkKey) private var scheduledBackupFolderBookmark: Data?
    @State private var isPickingBackupFolder = false
    @State private var hasStoredBackupPassphrase = false

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                wristProfileSection
                dataSection
                scheduledBackupSection
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
            .onAppear { hasStoredBackupPassphrase = KeychainHelper.readPassphrase() != nil }
            // Each fileExporter/fileImporter gets its own EmptyView anchor rather than being
            // stacked directly on this NavigationStack — multiple modifiers of the identical
            // kind attached to one view can collide in SwiftUI (only the last-attached one of
            // each kind ends up wired for presentation), which is what silently broke CSV
            // export/import here while the later-attached Backup ones worked.
            .background {
                EmptyView()
                    .fileExporter(isPresented: $isExportingCSV, document: csvExportDocument, contentType: .plainText, defaultFilename: "HorologyVaultWatches") { result in
                        if case .failure(let error) = result {
                            statusMessage = error.localizedDescription
                        }
                    }
            }
            .background {
                EmptyView()
                    .fileImporter(isPresented: $isImportingCSV, allowedContentTypes: [.plainText]) { result in
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
            }
            .background {
                EmptyView()
                    .fileExporter(isPresented: $isExportingBackup, document: backupExportDocument, contentType: .data, defaultFilename: "HorologyVaultBackup.hvbackup") { result in
                        if case .failure(let error) = result {
                            statusMessage = error.localizedDescription
                        }
                    }
            }
            .background {
                EmptyView()
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
            }
            .background {
                EmptyView()
                    .fileImporter(isPresented: $isPickingBackupFolder, allowedContentTypes: [.folder]) { result in
                        do {
                            let url = try result.get()
                            let didAccess = url.startAccessingSecurityScopedResource()
                            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                            scheduledBackupFolderBookmark = try ScheduledBackupManager.createFolderBookmark(for: url)
                        } catch {
                            statusMessage = error.localizedDescription
                        }
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
        case .settingScheduledBackupPassphrase: "Set Automatic Backup Passphrase"
        case nil: ""
        }
    }

    private var passphrasePromptMessage: String {
        switch passphrasePurpose {
        case .creatingBackup: "This passphrase encrypts your backup file. You'll need it again to restore it — don't lose it."
        case .restoringBackup: "Enter the passphrase used when this backup was created."
        case .settingScheduledBackupPassphrase: "Stored securely in the Keychain so automatic backups can run without prompting you each time. You'll need it to restore any backup this creates — don't lose it."
        case nil: ""
        }
    }

    private var passphraseConfirmLabel: String {
        switch passphrasePurpose {
        case .creatingBackup: "Create Backup"
        case .restoringBackup: "Restore"
        case .settingScheduledBackupPassphrase: "Save"
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
        case .settingScheduledBackupPassphrase:
            if KeychainHelper.savePassphrase(passphrase) {
                hasStoredBackupPassphrase = true
                statusMessage = "Automatic backup passphrase saved."
            } else {
                statusMessage = "Couldn't save the passphrase — try again."
            }
        }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        Section {
            Picker("Appearance", selection: $colorSchemePreference) {
                ForEach(ColorSchemePreference.allCases) { preference in
                    Text(preference.label).tag(preference)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 8) {
                Text("Accent Color")
                HStack(spacing: 10) {
                    ForEach(AccentColorOption.allCases) { option in
                        AccentColorSwatch(option: option, isSelected: option == accentColorOption) {
                            accentColorOption = option
                        }
                    }
                }
            }
        } header: {
            Text("Appearance")
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

    // MARK: Scheduled Backup

    private var scheduledBackupSection: some View {
        Section {
            Toggle("Automatic Backup", isOn: $isScheduledBackupEnabled)

            LabeledContent("Backup Folder") {
                Button(scheduledBackupFolderName) {
                    isPickingBackupFolder = true
                }
            }

            if isScheduledBackupEnabled {
                Picker("Frequency", selection: $scheduledBackupFrequency) {
                    ForEach(ScheduledBackupManager.BackupFrequency.allCases) { frequency in
                        Text(frequency.label).tag(frequency)
                    }
                }
            }

            Button(hasStoredBackupPassphrase ? "Change Backup Passphrase" : "Set Backup Passphrase") {
                passphrasePurpose = .settingScheduledBackupPassphrase
            }

            if hasStoredBackupPassphrase {
                Button("Remove Stored Passphrase", role: .destructive) {
                    KeychainHelper.deletePassphrase()
                    hasStoredBackupPassphrase = false
                }
            }
        } header: {
            Text("Scheduled Backup")
        } footer: {
            Text("Automatically saves an encrypted backup to the folder you choose, on the schedule above — no need to remember to do it manually. Needs a folder and a passphrase set first.")
        }
    }

    private var scheduledBackupFolderName: String {
        guard let bookmark = scheduledBackupFolderBookmark,
              let url = ScheduledBackupManager.resolveBookmarkedFolderURL(from: bookmark)
        else { return "Not Set" }
        return url.lastPathComponent
    }

    // MARK: Purchase Status

    private var isUnlocked: Bool {
        entitlements.first?.isLifetimeUnlocked ?? false
    }

    @ViewBuilder
    private var purchaseStatusSection: some View {
        Section {
            LabeledContent("Version") {
                if isUnlocked {
                    Label("Full Version", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .labelStyle(.titleAndIcon)
                } else {
                    Label("Demo (Read-Only)", systemImage: "lock")
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                }
            }
            if !isUnlocked {
                Button {
                    Task { await purchaseManager.purchase() }
                } label: {
                    if let product = purchaseManager.product {
                        Text("Unlock Full Version — \(product.displayPrice)")
                    } else {
                        Text("Unlock Full Version")
                    }
                }
                .disabled(purchaseManager.isLoadingProduct)
            }
            Button("Restore Purchase") {
                Task { await purchaseManager.restorePurchases() }
            }
            if let lastError = purchaseManager.lastError {
                Text(lastError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
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

/// A tappable circular color swatch used by the Appearance section's accent color picker,
/// matching the fixed-palette pattern Reminders/Notes use rather than an open-ended color picker.
private struct AccentColorSwatch: View {
    let option: AccentColorOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(option.color)
                .frame(width: 28, height: 28)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// User-facing override for the system color scheme; `.system` means "don't override" and maps to a
/// `nil` `ColorScheme` so `.preferredColorScheme` falls back to the OS setting.
enum ColorSchemePreference: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Predetermined accent color choices offered in Settings; a fixed 8-color palette rather than a
/// free-form color picker keeps every option legible in both light and dark mode without per-color
/// contrast testing (see Section 9 of the monetization plan).
enum AccentColorOption: String, CaseIterable, Identifiable {
    case blue, red, orange, yellow, green, teal, purple, pink

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .blue: .blue
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .teal: .teal
        case .purple: .purple
        case .pink: .pink
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
