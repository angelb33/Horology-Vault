//
//  NotificationManager.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/14/26.
//

import Foundation
import SwiftData
import UserNotifications

/// Schedules and cancels the local "service due" reminder for a `Watch`, driven by the
/// same due-date math as `Watch.isServiceDue`/`MaintenanceView`. No backend involved —
/// this is a V1, fully-local feature per the monetization plan.
enum NotificationManager {
    static func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        }
    }

    static func scheduleServiceDueReminder(for watch: Watch) {
        let center = UNUserNotificationCenter.current()
        let identifier = notificationIdentifier(for: watch)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard let dueDate = watch.serviceDueDate, dueDate > Date() else { return }

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
            .removePendingNotificationRequests(withIdentifiers: [notificationIdentifier(for: watch)])
    }

    /// Reschedules every watch's reminder — run once at launch so edits made outside the
    /// app's own CRUD flows (e.g. a restored backup) still end up with correct reminders.
    static func rescheduleAll(for watches: [Watch]) {
        for watch in watches {
            scheduleServiceDueReminder(for: watch)
        }
    }

    /// `persistentModelID` is stable for a given record from the moment it's inserted,
    /// which makes it a safe, no-schema-change-needed key for de-duplicating reminders.
    private static func notificationIdentifier(for watch: Watch) -> String {
        "service-due-\(String(describing: watch.persistentModelID))"
    }
}
