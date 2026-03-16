//
//  ActivityIntent.swift
//  RoutinelyWidgets
//
//  Created by Michael Edlund on 2026-03-11.
//

import AppIntents
import SwiftData
import SwiftUI
import WidgetKit
import UserNotifications

// MARK: - Activity Entity
struct ActivityEntity: AppEntity {
    let id: UUID
    let name: String
    let icon: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Activity")
    }

    static var defaultQuery: ActivityQuery {
        ActivityQuery()
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: name),
            image: .init(systemName: icon)
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

    @Parameter(title: "Activity ID", description: "The ID of the activity to complete")
    var activityID: String

    @Parameter(title: "Time Slot", description: "The time slot for this completion")
    var timeSlot: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Complete activity for time slot")
    }

    init() {}

    init(activityID: String, timeSlot: Int) {
        self.activityID = activityID
        self.timeSlot = timeSlot
    }

    func perform() async throws -> some IntentResult {
        // Access the shared SwiftData container via App Group
        let container = try ModelContainer(
            for: Activity.self, ActivityTimeSlot.self, Completion.self,
            configurations: ModelConfiguration(
                groupContainer: .identifier("group.com.medlund.Routinely")
            )
        )

        let context = ModelContext(container)

        // Find the activity by ID
        guard let uuid = UUID(uuidString: activityID) else {
            return .result()
        }

        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { $0.id == uuid }
        )

        guard let activity = try context.fetch(descriptor).first else {
            return .result()
        }

        // Get current weekday and time slot
        let currentWeekday = Calendar.current.component(.weekday, from: Date())
        guard let timeSlotEnum = TimeSlot(rawValue: timeSlot) else {
            return .result()
        }

        // Check if already completed
        if activity.isCompleted(for: currentWeekday, timeSlot: timeSlotEnum) {
            // Remove completion
            if let completion = activity.completions?.first(where: {
                $0.weekday == currentWeekday &&
                $0.timeSlot == timeSlotEnum &&
                Calendar.current.isDate($0.completedAt, equalTo: Date(), toGranularity: .weekOfYear)
            }) {
                context.delete(completion)
            }
        } else {
            // Add completion
            let completion = Completion(
                weekday: currentWeekday,
                timeSlot: timeSlotEnum,
                activity: activity
            )
            context.insert(completion)
        }

        try context.save()

        // Update badge count for current time slot
        await updateBadge(for: currentWeekday, timeSlot: timeSlotEnum, in: context)

        // Trigger widget timeline reload
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }

    private func updateBadge(for weekday: Int, timeSlot: TimeSlot, in context: ModelContext) async {
        // Fetch activities for current slot
        let descriptor = FetchDescriptor<ActivityTimeSlot>()
        guard let allSlots = try? context.fetch(descriptor) else {
            await MainActor.run {
                UNUserNotificationCenter.current().setBadgeCount(0)
            }
            return
        }

        let slots = allSlots.filter { $0.weekday == weekday && $0.timeSlot == timeSlot }
        let incompleteCount = slots.compactMap { $0.activity }.filter { activity in
            !activity.isCompleted(for: weekday, timeSlot: timeSlot)
        }.count

        await MainActor.run {
            UNUserNotificationCenter.current().setBadgeCount(incompleteCount)
        }
    }
}

// MARK: - Widget Configuration Intent
struct ConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Routinely Widget Configuration"
    static var description: IntentDescription = "Configure which time slot to display"

    @Parameter(title: "Time Slot", default: nil)
    var selectedTimeSlot: Int?
}
