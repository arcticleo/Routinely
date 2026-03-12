//
//  ActivityFormView.swift
//  Routinely
//
//  Created by Michael Edlund on 2026-03-11.
//

import SwiftUI
import SwiftData

// Represents a weekday + time slot combination
struct ScheduleSlot: Hashable {
    let weekday: Int  // 1 = Sunday, 2 = Monday, ... 7 = Saturday
    let timeSlot: TimeSlot
}

struct ActivityFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var activity: Activity?

    @State private var name: String = ""
    @State private var icon: String = "star.fill"
    @State private var selectedScheduleSlots: Set<ScheduleSlot> = []

    private var isEditing: Bool { activity != nil }

    private let commonIcons = [
        "star.fill", "heart.fill", "bolt.fill", "flame.fill", "drop.fill",
        "moon.fill", "sun.max.fill", "cloud.fill", "leaf.fill", "pawprint.fill",
        "figure.run", "figure.walk", "figure.mind.and.body",
        "book.fill", "pencil", "paintbrush.fill", "guitars.fill",
        "desktopcomputer", "iphone", "tv.fill", "gamecontroller.fill",
        "fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill",
        "bed.double.fill", "shower.fill", "tooth.fill",
        "cart.fill", "bag.fill", "gift.fill",
        "dollarsign.circle.fill", "creditcard.fill",
        "person.fill", "person.2.fill", "person.3.fill",
        "house.fill", "car.fill", "bicycle", "airplane",
        "phone.fill", "envelope.fill", "bubble.left.fill",
        "calendar", "clock.fill", "alarm.fill", "timer",
        "checkmark.circle.fill", "xmark.circle.fill",
        "exclamationmark.circle.fill", "questionmark.circle.fill"
    ]

    // Calendar weekdays (1 = Sunday, 2 = Monday, ... 7 = Saturday)
    private let weekdays = Array(1...7)

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Activity Name", text: $name)
                        .font(.headline)

                    IconPicker(selection: $icon, icons: commonIcons)
                }

                Section("Schedule") {
                    ScheduleGridPicker(
                        weekdays: weekdays,
                        timeSlots: TimeSlot.allCases,
                        selection: $selectedScheduleSlots
                    )
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            deleteActivity()
                        } label: {
                            Label("Delete Activity", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Activity" : "New Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveActivity()
                    }
                    .disabled(name.isEmpty || selectedScheduleSlots.isEmpty)
                }
            }
            .onAppear {
                if let activity = activity {
                    name = activity.name
                    icon = activity.icon
                    selectedScheduleSlots = Set(activity.timeSlots?.map {
                        ScheduleSlot(weekday: $0.weekday, timeSlot: $0.timeSlot)
                    } ?? [])
                }
            }
        }
    }

    private func saveActivity() {
        if let activity = activity {
            // Update existing activity
            activity.name = name
            activity.icon = icon

            // Update time slots: remove old ones not in selection
            let existingTimeSlots = activity.timeSlots ?? []
            let existingSet = Set(existingTimeSlots.map {
                ScheduleSlot(weekday: $0.weekday, timeSlot: $0.timeSlot)
            })

            // Remove time slots that are no longer selected
            for timeSlot in existingTimeSlots {
                let slot = ScheduleSlot(weekday: timeSlot.weekday, timeSlot: timeSlot.timeSlot)
                if !selectedScheduleSlots.contains(slot) {
                    modelContext.delete(timeSlot)
                }
            }

            // Add new time slots
            for scheduleSlot in selectedScheduleSlots {
                if !existingSet.contains(scheduleSlot) {
                    let newTimeSlot = ActivityTimeSlot(
                        weekday: scheduleSlot.weekday,
                        timeSlot: scheduleSlot.timeSlot,
                        activity: activity
                    )
                    modelContext.insert(newTimeSlot)
                }
            }
        } else {
            // Create new activity
            let newActivity = Activity(name: name, icon: icon)
            modelContext.insert(newActivity)

            // Create time slot associations
            for scheduleSlot in selectedScheduleSlots {
                let activityTimeSlot = ActivityTimeSlot(
                    weekday: scheduleSlot.weekday,
                    timeSlot: scheduleSlot.timeSlot,
                    activity: newActivity
                )
                modelContext.insert(activityTimeSlot)
            }
        }

        try? modelContext.save()
        dismiss()
    }

    private func deleteActivity() {
        if let activity = activity {
            modelContext.delete(activity)
            try? modelContext.save()
        }
        dismiss()
    }
}

// MARK: - Icon Picker
struct IconPicker: View {
    @Binding var selection: String
    let icons: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
            ForEach(icons, id: \.self) { icon in
                Button {
                    selection = icon
                } label: {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(selection == icon ? .white : .primary)
                        .frame(width: 44, height: 44)
                        .background(selection == icon ? Color.accentColor : Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Schedule Grid Picker
struct ScheduleGridPicker: View {
    let weekdays: [Int]
    let timeSlots: [TimeSlot]
    @Binding var selection: Set<ScheduleSlot>

    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

    var body: some View {
        VStack(spacing: 12) {
            // Header row with weekday names
            HStack(spacing: 4) {
                Text("Time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)

                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekdaySymbols[weekday - 1])
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.secondary)
                }
            }

            // Grid of time slots x weekdays
            ForEach(timeSlots, id: \.self) { timeSlot in
                HStack(spacing: 4) {
                    // Time slot label
                    HStack(spacing: 2) {
                        Image(systemName: timeSlot.defaultIcon)
                            .font(.caption2)
                        Text(timeSlot.displayName())
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .frame(width: 60, alignment: .leading)
                    .foregroundStyle(.secondary)

                    // Weekday columns
                    ForEach(weekdays, id: \.self) { weekday in
                        let slot = ScheduleSlot(weekday: weekday, timeSlot: timeSlot)
                        ScheduleCell(
                            slot: slot,
                            isSelected: selection.contains(slot),
                            color: timeSlot.swiftUIColor
                        ) {
                            toggleSlot(slot)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func toggleSlot(_ slot: ScheduleSlot) {
        if selection.contains(slot) {
            selection.remove(slot)
        } else {
            selection.insert(slot)
        }
    }
}

struct ScheduleCell: View {
    let slot: ScheduleSlot
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? color : Color(.systemGray5))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: 2)
                )
                .frame(height: 36)
                .overlay(
                    Image(systemName: isSelected ? "checkmark" : "")
                        .font(.caption)
                        .foregroundStyle(.white)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ActivityFormView(activity: nil)
        .modelContainer(for: [Activity.self, ActivityTimeSlot.self, Completion.self, UserPreferences.self], inMemory: true)
}
