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
                    Group {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundStyle(Color.white)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color Grid Picker
struct ColorPalettePicker: View {
    @Binding var selection: Color
    @Binding var icon: String
    @State private var showingColorGrid = false

    // Generate 64 web-safe colors (33, 66, 99, CC for each channel, excluding pure black/white)
    private let gridColors: [Color] = {
        let values: [UInt8] = [0x33, 0x66, 0x99, 0xCC]
        var colors: [(color: Color, brightness: Double, hue: Double)] = []

        for r in values {
            for g in values {
                for b in values {
                    // Skip pure black and pure white
                    if (r == 0x33 && g == 0x33 && b == 0x33) ||
                       (r == 0xCC && g == 0xCC && b == 0xCC) {
                        // Keep these - they're not pure black/white
                    }

                    let color = Color(red: Double(r) / 255.0,
                                     green: Double(g) / 255.0,
                                     blue: Double(b) / 255.0)

                    // Calculate brightness (luminance)
                    let brightness = 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)

                    // Calculate hue
                    let rd = Double(r) / 255.0
                    let gd = Double(g) / 255.0
                    let bd = Double(b) / 255.0
                    let maxVal = max(rd, max(gd, bd))
                    let minVal = min(rd, min(gd, bd))
                    let delta = maxVal - minVal

                    var hue: Double = 0
                    if delta > 0 {
                        if maxVal == rd {
                            hue = 60 * ((gd - bd) / delta + (gd < bd ? 6 : 0))
                        } else if maxVal == gd {
                            hue = 60 * ((bd - rd) / delta + 2)
                        } else {
                            hue = 60 * ((rd - gd) / delta + 4)
                        }
                    }

                    colors.append((color, brightness, hue))
                }
            }
        }

        // Sort by brightness (primary), then by hue (secondary)
        colors.sort { a, b in
            if a.brightness != b.brightness {
                return a.brightness < b.brightness
            }
            return a.hue < b.hue
        }

        return colors.map { $0.color }
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showingColorGrid = true
            } label: {
                HStack {
                    Image(systemName: icon.isEmpty ? "star.fill" : icon)
                        .font(.title2)
                        .foregroundStyle(selection)

                    Text(selection.toHex()?.uppercased() ?? "Custom")
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingColorGrid) {
            ColorGridSheet(selection: $selection, gridColors: gridColors, icon: icon)
        }
    }
}

struct ColorGridSheet: View {
    @Binding var selection: Color
    let gridColors: [Color]
    var icon: String
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 8)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Preview
                    HStack {
                        Spacer()
                        Image(systemName: icon.isEmpty ? "star.fill" : icon)
                            .font(.system(size: 60))
                            .foregroundStyle(selection)
                        Spacer()
                    }
                    .padding(.vertical, 10)

                    // Color Grid
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(0..<gridColors.count, id: \.self) { index in
                            let color = gridColors[index]
                            ColorGridCell(
                                color: color,
                                isSelected: isSelected(color)
                            ) {
                                selection = color
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical)
            }
            .navigationTitle("Choose Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func isSelected(_ color: Color) -> Bool {
        color.toHex()?.uppercased() == selection.toHex()?.uppercased()
    }
}

struct ColorGridCell: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 3)
                )
                .overlay(
                    Group {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(isLightColor(color) ? Color.black : Color.white)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    private func isLightColor(_ color: Color) -> Bool {
        guard let hex = color.toHex() else { return false }
        let r = Int(hex.dropFirst(1).prefix(2), radix: 16) ?? 0
        let g = Int(hex.dropFirst(3).prefix(2), radix: 16) ?? 0
        let b = Int(hex.dropFirst(5).prefix(2), radix: 16) ?? 0
        let brightness = 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
        return brightness > 128
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
