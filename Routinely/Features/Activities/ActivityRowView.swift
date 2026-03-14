//
//  ActivityRowView.swift
//  Routinely
//
//  Created by Michael Edlund on 2026-03-11.
//

import SwiftUI

struct ActivityRowView: View {
    let activity: Activity

    var body: some View {
        HStack {
            Image(systemName: activity.icon)
                .font(.title2)
                .foregroundStyle(activity.swiftUIColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.name)
                    .font(.headline)

                if let timeSlots = activity.timeSlots, !timeSlots.isEmpty {
                    let sortedSlots = timeSlots.sorted {
                        if $0.weekday != $1.weekday {
                            return $0.weekday < $1.weekday
                        }
                        return $0.timeSlot.rawValue < $1.timeSlot.rawValue
                    }
                    Text(scheduleLabels(for: sortedSlots))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func scheduleLabels(for timeSlots: [ActivityTimeSlot]) -> String {
        let calendar = Calendar.current
        let shortWeekdaySymbols = calendar.shortWeekdaySymbols

        // Group by weekday
        let byWeekday = Dictionary(grouping: timeSlots) { $0.weekday }
            .sorted { $0.key < $1.key }

        let labels = byWeekday.map { (weekday, slots) in
            let weekdayName = shortWeekdaySymbols[weekday - 1]
            let timeLabels = slots.map { $0.timeSlot.displayName() }.sorted().joined(separator: ", ")
            return "\(weekdayName)/\(timeLabels)"
        }

        return labels.joined(separator: ", ")
    }
}

#Preview {
    let activity = Activity(name: "Morning Exercise", icon: "figure.run")
    ActivityRowView(activity: activity)
}
