//
//  NotificationsAcknowledgment.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/17/26.
//

import Foundation

/// Tracks which of the Notifications panel's open issues the user has already seen, so the
/// sidebar bell's badge count only reflects what's *new* — without removing anything from the
/// panel's own list, which stays a live, complete view of every currently-open issue regardless
/// of acknowledgment state. A static-only enum with no stored state of its own (settings live in
/// `UserDefaults.standard` directly), matching `NotificationManager`/`ScheduledBackupManager`.
enum NotificationsAcknowledgment {
    static let acknowledgedKeysStorageKey = "acknowledgedNotificationKeys"

    /// How many of `watches`' currently-open issues (see `Watch.openNotificationKeys`) haven't
    /// been acknowledged yet.
    static func unacknowledgedCount(for watches: [Watch]) -> Int {
        let currentKeys = Set(watches.flatMap(\.openNotificationKeys))
        return currentKeys.subtracting(storedAcknowledgedKeys()).count
    }

    /// Snapshots every currently-open issue as acknowledged — the badge count drops to zero,
    /// but nothing is removed from the panel's list itself. This *replaces* the stored set
    /// rather than adding to it, which is what makes a resolved-then-reopened issue correctly
    /// count as new again later: its key simply won't be in the next snapshot once the issue
    /// resolves, so if it reopens, `unacknowledgedCount` sees it as unseen without any separate
    /// pruning/expiry step.
    static func acknowledgeAll(_ watches: [Watch]) {
        let currentKeys = watches.flatMap(\.openNotificationKeys)
        UserDefaults.standard.set(currentKeys.joined(separator: ","), forKey: acknowledgedKeysStorageKey)
    }

    private static func storedAcknowledgedKeys() -> Set<String> {
        let raw = UserDefaults.standard.string(forKey: acknowledgedKeysStorageKey) ?? ""
        guard !raw.isEmpty else { return [] }
        return Set(raw.split(separator: ",").map(String.init))
    }
}
