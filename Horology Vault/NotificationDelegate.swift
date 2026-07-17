//
//  NotificationDelegate.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/17/26.
//

import Foundation
import UserNotifications

/// Without an assigned delegate, iOS/macOS silently suppress a locally scheduled notification's
/// banner/sound if it fires while the app is already in the foreground — which is exactly what
/// happens whenever a reminder's trigger time arrives while the user has the app open (including
/// while actively debugging in Simulator). `willPresent` opts back into showing it anyway, which
/// is what a user actually expects from a reminder — there's no reason this app would want to
/// suppress them while active. `UNUserNotificationCenter.delegate` is a weak reference, so this
/// needs to be kept alive for the app's whole lifetime — `shared` plus assignment from
/// `Horology_Vault_App.init()` handles that, same early-assignment timing
/// `ScheduledBackupManager.registerBackgroundTask` already requires for the same reason (must
/// happen before the app finishes launching, not from a `View.task` like most other setup here).
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    private override init() {}

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
