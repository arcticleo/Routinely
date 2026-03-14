//
//  ActivityFormView.swift
//  Routinely
//
//  Created by Michael Edlund on 2026-03-11.
//

import SwiftUI
import SwiftData
import SFSymbols

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
    @State private var color: Color = .blue
    @State private var selectedScheduleSlots: Set<ScheduleSlot> = []

    private var isEditing: Bool { activity != nil }

    // Calendar weekdays (1 = Sunday, 2 = Monday, ... 7 = Saturday)
    private let weekdays = Array(1...7)

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Activity Name", text: $name)
                        .font(.headline)

                    SFSymbolPicker("Icon", selection: $icon)

                    ColorPalettePicker(selection: $color, icon: $icon)

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
                    color = activity.swiftUIColor
                    selectedScheduleSlots = Set(activity.timeSlots?.map {
                        ScheduleSlot(weekday: $0.weekday, timeSlot: $0.timeSlot)
                    } ?? [])
                }
            }
        }
    }

    private func saveActivity() {
        let hexColor = color.toHex() ?? "#007AFF"

        if let activity = activity {
            // Update existing activity
            activity.name = name
            activity.icon = icon
            activity.color = hexColor

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
            let newActivity = Activity(name: name, icon: icon, color: hexColor)
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
                        .foregroundStyle(Color.white)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color Palette Picker
struct ColorPalettePicker: View {
    @Binding var selection: Color
    @Binding var icon: String
    @State private var showingCustomColorPicker = false
    @State private var customColor: Color = .blue

    // White + ROYGBIV colors
    private let presetColors: [Color] = [
        .white,      // Default
        .red,        // R
        .orange,     // O
        .yellow,     // Y
        .green,      // G
        .blue,       // B
        .indigo,     // I
        .purple      // V (violet)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Preset color buttons (8 colors)
                    ForEach(0..<presetColors.count, id: \.self) { index in
                        let color = presetColors[index]
                        ColorButton(
                            color: color,
                            isSelected: isApproximatelyEqual(selection, color)
                        ) {
                            selection = color
                        }
                    }

                    // Custom color button
                    CustomColorButton(
                        selectedColor: selection,
                        isSelected: !isPresetColor(selection),
                        isCustomColor: !isPresetColor(selection)
                    ) {
                        customColor = selection
                        showingCustomColorPicker = true
                    }
                }
                .padding(.horizontal, 4)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        }
        .sheet(isPresented: $showingCustomColorPicker) {
            CustomColorPickerSheet(selection: $selection, customColor: $customColor, icon: icon)
        }
    }

    private func isPresetColor(_ color: Color) -> Bool {
        presetColors.contains { isApproximatelyEqual(color, $0) }
    }

    private func isApproximatelyEqual(_ c1: Color, _ c2: Color) -> Bool {
        // Convert to hex for comparison
        let h1 = c1.toHex() ?? ""
        let h2 = c2.toHex() ?? ""
        return h1 == h2
    }
}

struct ColorButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 3)
                )
                .overlay(
                    // Checkmark for white since border might not show well
                    Image(systemName: isSelected ? "checkmark" : "")
                        .font(.caption.bold())
                        .foregroundColor(color == Color.white ? Color.primary : Color.white)
                )
        }
        .buttonStyle(.plain)
    }
}

struct CustomColorButton: View {
    let selectedColor: Color
    let isSelected: Bool
    let isCustomColor: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // If custom color is selected, show it; otherwise show rainbow gradient
                if isCustomColor {
                    Circle()
                        .fill(selectedColor)
                        .frame(width: 32, height: 32)
                } else {
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                                center: .center
                            )
                        )
                        .frame(width: 32, height: 32)
                }

                // Selection ring
                Circle()
                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 3)
                    .frame(width: 32, height: 32)

                // Show plus if not custom color, checkmark if custom color is selected
                Image(systemName: isCustomColor ? "checkmark" : "plus")
                    .font(.caption.bold())
                    .foregroundStyle(isCustomColor && selectedColor != Color.white ? Color.white : Color.primary)
                    .shadow(radius: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct CustomColorPickerSheet: View {
    @Binding var selection: Color
    @Binding var customColor: Color
    var icon: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        Image(systemName: icon)
                            .font(.system(size: 60))
                            .foregroundStyle(customColor)
                        Spacer()
                    }
                    .padding(.vertical)
                }

                Section("Custom Color") {
                    ColorPicker("Select Color", selection: $customColor, supportsOpacity: false)
                        .labelsHidden()
                }
            }
            .navigationTitle("Custom Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selection = customColor
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Color Extension for Hex Conversion
extension Color {
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}

#Preview {
    ActivityFormView(activity: nil)
        .modelContainer(for: [Activity.self, ActivityTimeSlot.self, Completion.self, UserPreferences.self], inMemory: true)
}
