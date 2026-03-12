//
//  TimeSlot.swift
//  Routinely
//
//  Created by Michael Edlund on 2026-03-11.
//

import Foundation
import SwiftUI

enum TimeSlot: Int, Codable, CaseIterable {
    case midnightTo3am = 0    // 00:00 - 03:00
    case earlyMorning = 1    // 03:00 - 06:00
    case morning = 2         // 06:00 - 09:00
    case lateMorning = 3     // 09:00 - 12:00
    case afternoon = 4       // 12:00 - 15:00
    case lateAfternoon = 5   // 15:00 - 18:00
    case evening = 6         // 18:00 - 21:00
    case night = 7           // 21:00 - 00:00

    var startHour: Int {
        return self.rawValue * 3
    }

    var endHour: Int {
        return ((self.rawValue + 1) * 3) % 24
    }

    // Simple display showing just hours (e.g., "00-03", "06-09", "21-00")
    func displayName() -> String {
        let end = endHour == 0 ? 24 : endHour
        return String(format: "%02d-%02d", startHour, end)
    }

    // Default color for each time slot (user-overridable in settings)
    var defaultColor: String {
        switch self {
        case .midnightTo3am: return "#1a1a2e"    // Deep night blue
        case .earlyMorning: return "#16213e"   // Dark blue
        case .morning: return "#f4d03f"        // Morning yellow
        case .lateMorning: return "#f39c12"    // Late morning orange
        case .afternoon: return "#e74c3c"      // Afternoon red
        case .lateAfternoon: return "#9b59b6"  // Late afternoon purple
        case .evening: return "#3498db"        // Evening blue
        case .night: return "#2c3e50"          // Night slate
        }
    }

    // Default icon/SF Symbol for each time slot (user-overridable in settings)
    var defaultIcon: String {
        switch self {
        case .midnightTo3am: return "moon.stars.fill"
        case .earlyMorning: return "moon.fill"
        case .morning: return "sunrise.fill"
        case .lateMorning: return "sun.max.fill"
        case .afternoon: return "sun.max.fill"
        case .lateAfternoon: return "sunset.fill"
        case .evening: return "moon.fill"
        case .night: return "moon.zzz.fill"
        }
    }

    static var current: TimeSlot {
        let hour = Calendar.current.component(.hour, from: Date())
        return TimeSlot(rawValue: hour / 3) ?? .night
    }
}

extension TimeSlot {
    var swiftUIColor: Color {
        Color(hex: defaultColor) ?? .gray
    }
}

// Helper for hex color conversion
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
