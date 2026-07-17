//
//  Horology_Vault_App.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/10/26.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct Horology_Vault_App: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Watch.self,
            Strap.self,
            ServiceRecord.self,
            UserProfile.self,
            WishlistItem.self,
            WearLog.self,
            ProvenanceDoc.self,
            WindLog.self,
            CustomServiceCenter.self,
            Entitlements.self,
            ServiceContactOverride.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    /// `BGTaskScheduler` registration must happen before the app finishes launching — doing it
    /// later (e.g. from a `View.task`, like everything else here does its setup) is documented by
    /// Apple to silently fail. `sharedModelContainer`'s stored-property initializer above still
    /// runs before this body executes, so it's safe to reference here. The notification delegate
    /// assignment has the same "must happen early" requirement, for a different reason: without
    /// it assigned before a reminder's trigger date arrives, a notification firing while the app
    /// is in the foreground (e.g. while actively debugging) is silently suppressed entirely — see
    /// `NotificationDelegate`'s doc comment.
    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        #if os(iOS)
        ScheduledBackupManager.registerBackgroundTask(container: sharedModelContainer)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
