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
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic // Optional iCloud sync
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RoutinelyView()
        }
        .modelContainer(sharedModelContainer)
    }
}
