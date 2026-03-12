//
//  Activity.swift
//  Routinely
//
//  Created by Michael Edlund on 2026-03-11.
//

import Foundation
import SwiftData

@Model
class Activity {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String // SF Symbol name
    var createdAt: Date
    var sortOrder: Int

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \ActivityTimeSlot.activity)
    var timeSlots: [ActivityTimeSlot]?

    @Relationship(deleteRule: .cascade, inverse: \Completion.activity)
    var completions: [Completion]?

    init(name: String, icon: String) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.createdAt = Date()
        self.sortOrder = 0
    }

    /// Check if activity is completed for the given weekday and time slot
    /// - Parameters:
    ///   - weekday: The weekday (1 = Sunday, 2 = Monday, ... 7 = Saturday)
    ///   - timeSlot: The time slot to check
    ///   - date: The date within the target week (defaults to today)
    ///   - calendar: The calendar to use for week boundaries (respects user's firstWeekday preference)
    func isCompleted(for weekday: Int, timeSlot: TimeSlot, on date: Date = Date(), using calendar: Calendar? = nil) -> Bool {
        guard let completions = completions else { return false }
        let cal = calendar ?? Calendar.current
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart)!

        return completions.contains { completion in
            completion.weekday == weekday &&
            completion.timeSlot == timeSlot &&
            completion.completedAt >= weekStart &&
            completion.completedAt < weekEnd
        }
    }

    /// Convenience method for checking completion with just timeSlot (uses current weekday)
    func isCompleted(for timeSlot: TimeSlot, on date: Date = Date(), using calendar: Calendar? = nil) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return isCompleted(for: weekday, timeSlot: timeSlot, on: date, using: calendar)
    }
}
