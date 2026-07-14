//
//  Horology_Vault_App.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/10/26.
//

import SwiftUI
import SwiftData

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
            CustomServiceCenter.self,
            Entitlements.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
