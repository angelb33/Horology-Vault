//
//  ScheduledBackupManager.swift
//  Horology Vault
//
//  Created by Angel Burgos on 2026-07-15.
//

import Foundation
import SwiftData
#if os(iOS)
import BackgroundTasks
#endif

/// Automatic, silent encrypted backups on a user-chosen schedule — the manual "Encrypted Backup"
/// button in Settings still exists unchanged; this is a separate, opt-in path that reuses
/// `DataBackupManager.exportEncryptedBackup` with a Keychain-stored passphrase (see
/// `KeychainHelper`) instead of prompting each time, since a silent background run can't show a
/// passphrase prompt. A static-only enum with no stored state, matching `NotificationManager`/
/// `DataBackupManager` — settings live in `UserDefaults.standard` directly (the same store
/// `@AppStorage` reads/writes) since a static enum can't hold `@AppStorage` itself.
enum ScheduledBackupManager {
    enum BackupFrequency: String, CaseIterable, Identifiable {
        case daily, weekly, monthly

        var id: String { rawValue }

        var label: String {
            switch self {
            case .daily: "Daily"
            case .weekly: "Weekly"
            case .monthly: "Monthly"
            }
        }

        fileprivate var dateComponent: Calendar.Component {
            switch self {
            case .daily: .day
            case .weekly: .weekOfYear
            case .monthly: .month
            }
        }
    }

    // MARK: - UserDefaults keys (same store @AppStorage in SettingsView/ContentView reads)

    static let enabledKey = "scheduledBackupEnabled"
    static let frequencyKey = "scheduledBackupFrequency"
    static let lastRunTimestampKey = "scheduledBackupLastRunTimestamp"
    static let folderBookmarkKey = "scheduledBackupFolderBookmark"

    private static let backgroundTaskIdentifier = "com.angelburgos.HorologyVault.scheduledBackup"

    // MARK: - Due-date math (pure, testable — no UserDefaults/Keychain/file I/O)

    /// `lastRunDate == nil` (never run before) is always due. Otherwise due once a full
    /// `frequency` interval has elapsed since `lastRunDate`, measured in calendar units (a
    /// "Monthly" backup means a calendar month, not a flat 30-day count, so it doesn't drift
    /// against what a user means by "once a month").
    static func isBackupDue(
        frequency: BackupFrequency,
        lastRunDate: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let lastRunDate else { return true }
        guard let nextDue = calendar.date(byAdding: frequency.dateComponent, value: 1, to: lastRunDate) else {
            return true
        }
        return nextDue <= now
    }

    // MARK: - Folder bookmark

    /// Resolves with `.withSecurityScope` on macOS so the returned URL can actually be written to
    /// — that option doesn't exist on iOS, where document-picker-provided URLs are implicitly
    /// security-scoped without needing to opt in. Treats a stale bookmark as a failure (returns
    /// `nil`) rather than silently writing to a location that may no longer be what the user
    /// picked — the caller should prompt the user to re-choose a folder rather than guessing.
    static func resolveBookmarkedFolderURL(from bookmarkData: Data) -> URL? {
        var isStale = false
        #if os(macOS)
        let options: URL.BookmarkResolutionOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkResolutionOptions = []
        #endif
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: options,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ), !isStale else { return nil }
        return url
    }

    /// Creates a persistable bookmark for `url` (a folder the user just picked via
    /// `.fileImporter`), mirroring the macOS/iOS `.withSecurityScope` difference described above.
    static func createFolderBookmark(for url: URL) throws -> Data {
        #if os(macOS)
        let options: URL.BookmarkCreationOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkCreationOptions = []
        #endif
        return try url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    // MARK: - Orchestration

    /// Checks whether a backup is due and, if so, performs one end to end. Returns `true` only on
    /// a fully successful run (export succeeded and the file was written) — a missing passphrase,
    /// unresolvable bookmark, or write failure leaves the due-check retriable next time rather
    /// than marking a failed cycle as done.
    ///
    /// Gated behind `Entitlements.isLifetimeUnlocked` — checked here too, not just in
    /// `SettingsView`'s UI, so a background run can't slip through for a user whose entitlement
    /// lapsed (e.g. a refund) after they'd already enabled the toggle.
    @discardableResult
    static func performBackupIfDue(context: ModelContext, now: Date = Date()) -> Bool {
        let isUnlocked = (try? context.fetch(FetchDescriptor<Entitlements>()))?.first?.isLifetimeUnlocked ?? false
        guard isUnlocked else { return false }

        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: enabledKey) else { return false }

        let frequency = BackupFrequency(rawValue: defaults.string(forKey: frequencyKey) ?? "") ?? .weekly
        let lastRunTimestamp = defaults.double(forKey: lastRunTimestampKey)
        let lastRunDate = lastRunTimestamp > 0 ? Date(timeIntervalSince1970: lastRunTimestamp) : nil
        guard isBackupDue(frequency: frequency, lastRunDate: lastRunDate, now: now) else { return false }

        guard let bookmarkData = defaults.data(forKey: folderBookmarkKey),
              let folderURL = resolveBookmarkedFolderURL(from: bookmarkData)
        else { return false }

        guard folderURL.startAccessingSecurityScopedResource() else { return false }
        defer { folderURL.stopAccessingSecurityScopedResource() }

        guard let passphrase = KeychainHelper.readPassphrase() else { return false }

        do {
            let sealedData = try DataBackupManager.exportEncryptedBackup(context: context, passphrase: passphrase)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let fileURL = folderURL.appendingPathComponent("HorologyVaultBackup-\(formatter.string(from: now)).hvbackup")
            try sealedData.write(to: fileURL)
        } catch {
            return false
        }

        defaults.set(now.timeIntervalSince1970, forKey: lastRunTimestampKey)
        return true
    }

    // MARK: - Platform scheduling

    #if os(iOS)
    /// Must be called before the app finishes launching (from `Horology_Vault_App.init()`, not a
    /// `View.task`) — BGTaskScheduler registration is documented by Apple to silently fail if
    /// done any later.
    static func registerBackgroundTask(container: ModelContainer) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            let context = ModelContext(container)
            let success = performBackupIfDue(context: context)
            scheduleNextBackgroundTask()
            processingTask.setTaskCompleted(success: success)
        }
        scheduleNextBackgroundTask()
    }

    /// BGTaskScheduler requests are one-shot, not naturally recurring — re-submitted after every
    /// registration and every run so there's always a pending request. The OS decides the actual
    /// fire time (opportunistic, not exact), which is why `performBackupIfDue` is also called at
    /// launch as a catch-up (see `ContentView.task`) rather than relying on this alone.
    static func scheduleNextBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        try? BGTaskScheduler.shared.submit(request)
    }
    #endif

    #if os(macOS)
    private static var backgroundActivityScheduler: NSBackgroundActivityScheduler?

    /// Runs while the app is alive (foreground or background) — this app explicitly doesn't need
    /// scheduled backups to happen while fully quit, so there's no LaunchAgent/SMAppService helper
    /// here. The actual frequency the user configured is enforced by `performBackupIfDue`'s
    /// due-check; this just needs to check "often enough" that a Daily-configured backup doesn't
    /// slip by unnoticed while the app happens to be running.
    static func startBackgroundActivityScheduler(context: ModelContext) {
        guard backgroundActivityScheduler == nil else { return }
        let scheduler = NSBackgroundActivityScheduler(identifier: backgroundTaskIdentifier)
        scheduler.repeats = true
        scheduler.interval = 60 * 60
        scheduler.qualityOfService = .utility
        scheduler.schedule { completion in
            _ = performBackupIfDue(context: context)
            completion(.finished)
        }
        backgroundActivityScheduler = scheduler
    }
    #endif
}
