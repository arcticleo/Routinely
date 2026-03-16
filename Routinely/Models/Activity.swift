//
//  Activity.swift
//  Routinely
//
//  Created by Michael Edlund on 2026-03-11.
//

import Foundation
import SwiftData
import SwiftUI

@Model
class Activity {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String // SF Symbol name
    var color: String // Hex color code (e.g., "#FF5733")
    var createdAt: Date
    var sortOrder: Int

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \ActivityTimeSlot.activity)
    var timeSlots: [ActivityTimeSlot]?

    @Relationship(deleteRule: .cascade, inverse: \Completion.activity)
    var completions: [Completion]?

    init(name: String, icon: String, color: String = "#007AFF") {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.color = color
        self.createdAt = Date()
        self.sortOrder = 0
    }

    /// SwiftUI Color from hex string
    var swiftUIColor: Color {
        Color(hex: color) ?? .blue
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

    /// Add sample activities for development/testing
    /// - Parameter context: The ModelContext to insert the samples into
    @MainActor
    static func addSamples(to context: ModelContext) {
        // Sample activity definitions with their schedule
        // 64 web-safe colors from the picker palette (0x33, 0x66, 0x99, 0xCC for each channel)
        let samples: [(name: String, icon: String, color: String, slots: [(weekday: Int, timeSlot: TimeSlot)])] = [
            // Fill Water Bottle: All days, 06-09
            (
                "Fill Water Bottle",
                "drop.fill",
                "#3399CC", // Blue
                Array(1...7).flatMap { day in [(day, .morning)] }
            ),
            // Bleach: Mon/06-09, Tue/09-12, Wed/06-09, Thu-Sun/06-09
            (
                "Bleach",
                "sparkles",
                "#CC3333", // Red
                [
                    (2, .morning),      // Mon 06-09
                    (3, .lateMorning),  // Tue 09-12
                    (4, .morning),      // Wed 06-09
                    (5, .lateMorning),      // Thu 06-09
                    (6, .lateMorning),      // Fri 06-09
                    (7, .lateMorning),      // Sat 06-09
                    (1, .lateMorning),      // Sun 06-09
                ]
            ),
            // Clean/Organize Something: Tue/Thu/Fri/Sat/Sun, 09-12/12-15/15-18/18-21
            (
                "Clean/Organize Something",
                "arrow.3.trianglepath",
                "#66CCFF", // Ice blue
                [3, 5, 6, 7, 1].flatMap { day in
                    [.lateMorning, .afternoon, .lateAfternoon, .evening].map { (day, $0) }
                }
            ),
            // Topz Around Sink: Sun/09-12
            (
                "Topz Around Sink",
                "sink",
                "#33CC99", // Mint
                [1].map { ($0, .lateMorning) }
            ),
            // Absorption Block: Tue/Thu/Fri/Sat/Sun 09-12
            (
                "Absorption Block",
                "pills.fill",
                "#9966CC", // Purple
                [3, 5, 6, 7, 1].map { ($0, .lateMorning) }
            ),
            // Multivitamin Block: Tue/Thu/Fri/Sat/Sun 12-15
            (
                "Multivitamin Block",
                "capsule.fill",
                "#33CC66", // Green
                [3, 5, 6, 7, 1].map { ($0, .afternoon) }
            ),
            // Fiber Block: Tue/Thu/Fri/Sat/Sun 15-18
            (
                "Fiber Block",
                "leaf.fill",
                "#339966", // Dark Green
                [3, 5, 6, 7, 1].map { ($0, .lateAfternoon) }
            ),
            // Minerals Block: Tue/Thu/Fri/Sat/Sun 21-00
            (
                "Minerals Block",
                "bolt.heart.fill",
                "#336699", // Dark Blue/Gray
                [3, 5, 6, 7, 1].map { ($0, .night) }
            ),
        ]

        // Create activities and their time slots
        for (index, sample) in samples.enumerated() {
            let activity = Activity(name: sample.name, icon: sample.icon, color: sample.color)
            activity.sortOrder = index
            context.insert(activity)

            for (weekday, timeSlot) in sample.slots {
                let activityTimeSlot = ActivityTimeSlot(
                    weekday: weekday,
                    timeSlot: timeSlot,
                    activity: activity
                )
                context.insert(activityTimeSlot)
            }
        }

        try? context.save()
    }
}
