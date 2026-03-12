//
//  UserPreferences.swift
//  Routinely
//
//  Created by Michael Edlund on 2026-03-11.
//

import Foundation
import SwiftData

@Model
class UserPreferences {
    @Attribute(.unique) var id: UUID

    // First day of week: 1 = Sunday, 2 = Monday, etc.
    // Defaults to device setting via Calendar.current.firstWeekday
    var firstWeekday: Int?

    // Time format preference: nil = follow device locale, true = 24h, false = 12h
    var use24HourClock: Bool?

    // Locale override: nil = follow device, otherwise use this locale identifier
    var localeIdentifier: String?

    // Time slot customization (user overrides for defaults)
    var timeSlotColors: [Int: String]?  // timeSlot.rawValue -> hex color
    var timeSlotIcons: [Int: String]?   // timeSlot.rawValue -> SF Symbol name

    init() {
        self.id = UUID()
    }

    /// Returns the user's preferred calendar, respecting firstWeekday setting
    var calendar: Calendar {
        var cal = Calendar.current
        if let firstWeekday = firstWeekday {
            cal.firstWeekday = firstWeekday
        }
        if let localeId = localeIdentifier {
            cal.locale = Locale(identifier: localeId)
        }
        return cal
    }

    /// Returns the appropriate time style based on user preference
    var timeStyle: DateFormatter.Style {
        // DateIntervalFormatter doesn't support explicit 12/24h toggle,
        // but we can influence it via locale. For strict control,
        // we'd need a custom formatter in the UI layer.
        return .short
    }
}

// Calendar extension for user preferences
extension Calendar {
    static func forUser(_ preferences: UserPreferences?) -> Calendar {
        var calendar = Calendar.current
        if let firstWeekday = preferences?.firstWeekday {
            calendar.firstWeekday = firstWeekday
        }
        if let localeId = preferences?.localeIdentifier {
            calendar.locale = Locale(identifier: localeId)
        }
        return calendar
    }
}
