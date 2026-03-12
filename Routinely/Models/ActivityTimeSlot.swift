//
//  ActivityTimeSlot.swift
//  Routinely
//
//  Created by Michael Edlund on 2026-03-11.
//

import Foundation
import SwiftData

@Model
class ActivityTimeSlot {
    @Attribute(.unique) var id: UUID
    var weekday: Int  // 1 = Sunday, 2 = Monday, ... 7 = Saturday (matches Calendar weekday)
    var timeSlot: TimeSlot

    @Relationship
    var activity: Activity?

    init(weekday: Int, timeSlot: TimeSlot, activity: Activity) {
        self.id = UUID()
        self.weekday = weekday
        self.timeSlot = timeSlot
        self.activity = activity
    }
}

// MARK: - Weekday Helpers
extension ActivityTimeSlot {
    var weekdayName: String {
        Calendar.current.weekdaySymbols[weekday - 1]
    }

    var shortWeekdayName: String {
        Calendar.current.shortWeekdaySymbols[weekday - 1]
    }

    var veryShortWeekdayName: String {
        Calendar.current.veryShortWeekdaySymbols[weekday - 1]
    }
}
