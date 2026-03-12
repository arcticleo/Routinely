//
//  CompletionButton.swift
//  Routinely
//
//  Created by Michael Edlund on 2026-03-11.
//

import SwiftUI
import SwiftData

struct CompletionButton: View {
    let activity: Activity
    let timeSlot: TimeSlot
    let weekday: Int  // 1 = Sunday, 2 = Monday, ... 7 = Saturday

    @Environment(\.modelContext) private var modelContext

    var isCompleted: Bool {
        activity.isCompleted(for: timeSlot)
    }

    var body: some View {
        Button {
            toggleCompletion()
        } label: {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .symbolRenderingMode(.palette)
                .foregroundStyle(isCompleted ? .white : .secondary, timeSlot.swiftUIColor)
                .font(.title2)
        }
        .buttonStyle(.borderless)
        .contentTransition(.symbolEffect(.replace))
        .sensoryFeedback(.success, trigger: isCompleted)
    }

    private func toggleCompletion() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if isCompleted {
                // Remove completion for this weekday/time slot this week
                if let completion = activity.completions?.first(where: {
                    $0.weekday == weekday &&
                    $0.timeSlot == timeSlot &&
                    Calendar.current.isDate($0.completedAt, equalTo: Date(), toGranularity: .weekOfYear)
                }) {
                    modelContext.delete(completion)
                }
            } else {
                // Add completion with weekday
                let completion = Completion(weekday: weekday, timeSlot: timeSlot, activity: activity)
                modelContext.insert(completion)
            }
            try? modelContext.save()
        }
    }
}

#Preview {
    let activity = Activity(name: "Morning Exercise", icon: "figure.run")
    CompletionButton(activity: activity, timeSlot: .morning, weekday: 2) // Monday
        .modelContainer(for: [Activity.self, ActivityTimeSlot.self, Completion.self, UserPreferences.self], inMemory: true)
}
