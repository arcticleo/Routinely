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
    
    // Punt tracking for one-off time slot changes
    var isPunted: Bool = false
    var originalTimeSlot: TimeSlot?  // The original scheduled time slot before punt
    var puntedWeekOfYear: Int?       // Week number when punted (to expire after week ends)
    var puntedYear: Int?             // Year for week of year (to handle year boundaries)

    @Relationship
    var activity: Activity?

    init(weekday: Int, timeSlot: TimeSlot, activity: Activity) {
        self.id = UUID()
        self.weekday = weekday
        self.timeSlot = timeSlot
        self.activity = activity
        self.isPunted = false
        self.originalTimeSlot = nil
        self.puntedWeekOfYear = nil
        self.puntedYear = nil
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

// MARK: - Punt Helpers
extension ActivityTimeSlot {
    /// Punts this activity to the next time slot for the current week only
    func punt(to newTimeSlot: TimeSlot) {
        guard !isPunted else { return }  // Already punted, don't punt again
        
        let calendar = Calendar.current
        let now = Date()
        
        self.isPunted = true
        self.originalTimeSlot = self.timeSlot
        self.timeSlot = newTimeSlot
        self.puntedYear = calendar.component(.yearForWeekOfYear, from: now)
        self.puntedWeekOfYear = calendar.component(.weekOfYear, from: now)
    }
    
    /// Checks if the punt has expired (week has ended) and resets if needed
    func checkAndClearExpiredPunt() {
        guard isPunted else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.yearForWeekOfYear, from: now)
        let currentWeek = calendar.component(.weekOfYear, from: now)
        
        // If we're in a different week, clear the punt
        if currentYear != puntedYear || currentWeek != puntedWeekOfYear {
            clearPunt()
        }
    }
    
    /// Clears the punt and restores original time slot
    func clearPunt() {
        guard isPunted, let original = originalTimeSlot else { return }
        
        self.timeSlot = original
        self.isPunted = false
        self.originalTimeSlot = nil
        self.puntedWeekOfYear = nil
        self.puntedYear = nil
    }
    
    /// Returns the effective time slot for display (considers punt status)
    func effectiveTimeSlot() -> TimeSlot {
        if isPunted {
            checkAndClearExpiredPunt()
        }
        return timeSlot
    }
}
