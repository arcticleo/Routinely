//
//  Completion.swift
//  Routinely
//
//  Created by Michael Edlund on 2026-03-11.
//

import Foundation
import SwiftData

@Model
class Completion {
    @Attribute(.unique) var id: UUID
    var completedAt: Date
    var weekday: Int      // 1 = Sunday, 2 = Monday, ... 7 = Saturday
    var timeSlot: TimeSlot

    @Relationship
    var activity: Activity?

    init(weekday: Int, timeSlot: TimeSlot, activity: Activity, completedAt: Date = Date()) {
        self.id = UUID()
        self.weekday = weekday
        self.timeSlot = timeSlot
        self.activity = activity
        self.completedAt = completedAt
    }
}
