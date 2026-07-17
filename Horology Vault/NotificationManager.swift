//
//  NotificationManager.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/14/26.
//

import Foundation
import SwiftData
import UserNotifications

/// Schedules and cancels the local "service due" and "wind reminder" notifications for a
/// `Watch`. Both are gated behind `isUnlocked` (the app's one-time lifetime-unlock
/// entitlement) — callers pass their own `Entitlements.isLifetimeUnlocked` read rather than
/// this static enum querying SwiftData itself, matching how `ScheduledBackupManager` takes
/// its gating input from the caller instead of reaching into `@AppStorage`/`@Query` directly.
/// No backend involved either way — this is a V1, fully-local feature per the monetization plan.
/// User-facing enable/disable toggles and the service interval have two layers: an app-wide
/// master switch in Settings (`UserDefaults.standard`, the same store `@AppStorage` there
/// reads/writes, since a static enum can't hold `@AppStorage` itself — same pattern as
/// `ScheduledBackupManager`'s keys), and a per-watch override (`Watch.isServiceDueReminderEnabled`/
/// `isWindReminderEnabled`, set from the Workbench's Reminders section). Both must allow a
/// reminder for it to fire — the master switch is an AND gate, not a fallback: turning it off
/// silences every watch regardless of that watch's own setting, and turning it back on restores
/// each watch's individual choice rather than force-enabling everything.
enum NotificationManager {
    // MARK: - UserDefaults keys (same store @AppStorage in SettingsView reads)

    static let isServiceDueReminderEnabledKey = "isServiceDueReminderEnabled"
    static let isWindReminderEnabledKey = "isWindReminderEnabled"
    static let serviceIntervalYearsKey = "serviceIntervalYears"
    static let defaultServiceIntervalYears = 5

    static func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        }
    }

    /// The gating decision itself, pulled out as a pure function — same reasoning `FitCalculator`/
    /// `PurchaseManager.updateEntitlementsRecord` were extracted for: this used to be inline
    /// inside `scheduleServiceDueReminder` and, because it touched `UNUserNotificationCenter`
    /// directly, was completely untested (only the `Watch.serviceDueDate` it reads was). Returns
    /// the date to schedule for, or `nil` if any gate fails or the date's already past.
    static func resolvedServiceDueDate(
        isUnlocked: Bool,
        globallyEnabled: Bool,
        perWatchEnabled: Bool,
        dueDate: Date?,
        now: Date = Date()
    ) -> Date? {
        guard isUnlocked, globallyEnabled, perWatchEnabled else { return nil }
        guard let dueDate, dueDate > now else { return nil }
        return dueDate
    }

    static func scheduleServiceDueReminder(for watch: Watch, isUnlocked: Bool) {
        let center = UNUserNotificationCenter.current()
        let identifier = serviceDueIdentifier(for: watch)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let globallyEnabled = UserDefaults.standard.object(forKey: isServiceDueReminderEnabledKey) as? Bool ?? true
        guard let dueDate = resolvedServiceDueDate(
            isUnlocked: isUnlocked,
            globallyEnabled: globallyEnabled,
            perWatchEnabled: watch.isServiceDueReminderEnabled ?? true,
            dueDate: watch.serviceDueDate
        ) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Service Due"
        content.body = "\(watch.brand) \(watch.model) is due for service."
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    static func cancelServiceDueReminder(for watch: Watch) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [serviceDueIdentifier(for: watch)])
    }

    /// Same reasoning as `resolvedServiceDueDate`.
    static func resolvedWindReminderDate(
        isUnlocked: Bool,
        globallyEnabled: Bool,
        perWatchEnabled: Bool,
        windReminderDate: Date?,
        now: Date = Date()
    ) -> Date? {
        guard isUnlocked, globallyEnabled, perWatchEnabled else { return nil }
        guard let windReminderDate, windReminderDate > now else { return nil }
        return windReminderDate
    }

    static func scheduleWindReminder(for watch: Watch, isUnlocked: Bool) {
        let center = UNUserNotificationCenter.current()
        let identifier = windReminderIdentifier(for: watch)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let globallyEnabled = UserDefaults.standard.object(forKey: isWindReminderEnabledKey) as? Bool ?? true
        guard let reminderDate = resolvedWindReminderDate(
            isUnlocked: isUnlocked,
            globallyEnabled: globallyEnabled,
            perWatchEnabled: watch.isWindReminderEnabled ?? true,
            windReminderDate: watch.windReminderDate
        ) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Wind Reminder"
        content.body = "\(watch.brand) \(watch.model)'s power reserve is about to run out — time to wind it."
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    static func cancelWindReminder(for watch: Watch) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [windReminderIdentifier(for: watch)])
    }

    /// A one-off reminder for `maintenanceExpectedPickupDate` — unlike Service Due/Wind, there's
    /// no separate app-wide master switch or per-watch toggle for this one; it's a transactional
    /// appointment reminder (only exists while a watch is actually checked in for maintenance)
    /// rather than a recurring, always-on setting, so the extra configuration layer didn't seem
    /// worth it. Still gated behind `isUnlocked`, same as the other two.
    /// Same reasoning as `resolvedServiceDueDate`, minus the two enable-toggle gates this
    /// reminder deliberately doesn't have — see this function's own doc comment above.
    static func resolvedPickupReminderDate(
        isUnlocked: Bool,
        expectedPickupDate: Date?,
        now: Date = Date()
    ) -> Date? {
        guard isUnlocked else { return nil }
        guard let expectedPickupDate, expectedPickupDate > now else { return nil }
        return expectedPickupDate
    }

    static func schedulePickupReminder(for watch: Watch, isUnlocked: Bool) {
        let center = UNUserNotificationCenter.current()
        let identifier = pickupReminderIdentifier(for: watch)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard let pickupDate = resolvedPickupReminderDate(
            isUnlocked: isUnlocked,
            expectedPickupDate: watch.maintenanceExpectedPickupDate
        ) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Ready for Pickup"
        content.body = "\(watch.brand) \(watch.model) should be ready to pick up from maintenance today."
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: pickupDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    static func cancelPickupReminder(for watch: Watch) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [pickupReminderIdentifier(for: watch)])
    }

    /// Reschedules every watch's reminders — run once at launch, and again whenever the
    /// lifetime-unlock entitlement changes, so a mid-session purchase activates reminders
    /// immediately rather than requiring a relaunch, and edits made outside the app's own
    /// CRUD flows (e.g. a restored backup) still end up with correct reminders.
    static func rescheduleAll(for watches: [Watch], isUnlocked: Bool) {
        for watch in watches {
            scheduleServiceDueReminder(for: watch, isUnlocked: isUnlocked)
            scheduleWindReminder(for: watch, isUnlocked: isUnlocked)
            schedulePickupReminder(for: watch, isUnlocked: isUnlocked)
        }
    }

    /// `persistentModelID` is stable for a given record from the moment it's inserted,
    /// which makes it a safe, no-schema-change-needed key for de-duplicating reminders.
    private static func serviceDueIdentifier(for watch: Watch) -> String {
        "service-due-\(String(describing: watch.persistentModelID))"
    }

    private static func windReminderIdentifier(for watch: Watch) -> String {
        "wind-reminder-\(String(describing: watch.persistentModelID))"
    }

    private static func pickupReminderIdentifier(for watch: Watch) -> String {
        "pickup-reminder-\(String(describing: watch.persistentModelID))"
    }
}
