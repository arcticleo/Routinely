//
//  RoutinelyApp.swift
//  Routinely
//
//  Created by Michael Edlund on 2026-03-11.
//

import SwiftUI
import SwiftData

@main
struct RoutinelyApp: App {
    // App Group identifier for shared container between app and widgets
    // NOTE: This must be configured in the project's Signing & Capabilities
    static let appGroupIdentifier = "group.com.medlund.Routinely"

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Activity.self,
            ActivityTimeSlot.self,
            Completion.self,
            UserPreferences.self,
        ], version: Schema.Version(1, 0, 0))

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic // Optional iCloud sync
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If migration fails, delete the old store and recreate (development only!)
            #if DEBUG
            print("Failed to create ModelContainer: \(error)")
            print("Deleting old store and creating fresh persistent container...")

            // Delete the store files
            let storeURL = modelConfiguration.url
            try? FileManager.default.removeItem(at: storeURL)

            // Try again with a fresh persistent store
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer even after reset: \(error)")
            }
            #else
            fatalError("Could not create ModelContainer: \(error)")
            #endif
        }
    }()

    var body: some Scene {
        WindowGroup {
            RoutinelyView()
        }
        .modelContainer(sharedModelContainer)
    }
}
