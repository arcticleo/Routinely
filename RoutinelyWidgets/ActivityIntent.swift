//
//  ActivityIntent.swift
//  RoutinelyWidgets
//
//  Created by Michael Edlund on 2026-03-11.
//

import AppIntents
import SwiftData
import SwiftUI

// MARK: - Activity Entity
struct ActivityEntity: AppEntity {
    let id: UUID
    let name: String
    let icon: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Activity")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: name),
            image: .init(systemName: icon) ?? .init(systemName: "star")
        )
    }
}

// MARK: - Activity Query
struct ActivityQuery: EntityQuery {
    func entities(for identifiers: [ActivityEntity.ID]) async throws -> [ActivityEntity] {
        // This would query SwiftData from the widget context
        // For now, return empty
        return []
    }

    func suggestedEntities() async throws -> [ActivityEntity] {
        // Return suggested activities for the current time slot
        return []
    }
}

// MARK: - Complete Activity Intent
struct CompleteActivityIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Activity"
    static var description: IntentDescription = "Mark an activity as completed for the current time slot."

    @Parameter(title: "Activity", description: "The activity to complete")
    var activity: ActivityEntity

    @Parameter(title: "Time Slot", description: "The time slot for this completion")
    var timeSlot: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Complete \(\$activity) for time slot \(\$timeSlot)")
    }

    func perform() async throws -> some IntentResult {
        // This will be called when user taps the widget completion button
        // The actual implementation needs to access the shared SwiftData container

        // For now, return success
        return .result()
    }
}

// MARK: - Widget Configuration Intent
struct ConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Routinely Widget Configuration"
    static var description: IntentDescription = "Configure which time slot to display"

    @Parameter(title: "Time Slot", default: nil)
    var selectedTimeSlot: Int?
}
