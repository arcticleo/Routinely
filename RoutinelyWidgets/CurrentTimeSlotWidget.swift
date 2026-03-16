//
//  CurrentTimeSlotWidget.swift
//  RoutinelyWidgets
//
//  Created by Michael Edlund on 2026-03-11.
//

import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

struct Provider: TimelineProvider {
    let container: ModelContainer

    init() {
        // Access the shared SwiftData container via App Group
        self.container = try! ModelContainer(
            for: Activity.self, ActivityTimeSlot.self, Completion.self, UserPreferences.self,
            configurations: ModelConfiguration(
                groupContainer: .identifier("group.com.medlund.Routinely")
            )
        )
    }

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), timeSlot: .morning, activities: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let entry = fetchEntry(for: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let currentDate = Date()
        let entry = fetchEntry(for: currentDate)

        // Calculate next time slot change (every 3 hours)
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: currentDate)
        let nextSlotHour = ((currentHour / 3) + 1) * 3
        var components = calendar.dateComponents([.year, .month, .day], from: currentDate)
        components.hour = nextSlotHour % 24
        components.minute = 0
        components.second = 0

        let nextUpdate = calendar.date(from: components)!

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func fetchEntry(for date: Date) -> SimpleEntry {
        let context = ModelContext(container)
        let currentWeekday = Calendar.current.component(.weekday, from: date)
        let currentTimeSlot = TimeSlot.current

        // Fetch all activity time slots
        let descriptor = FetchDescriptor<ActivityTimeSlot>()
        guard let allSlots = try? context.fetch(descriptor) else {
            return SimpleEntry(date: date, timeSlot: currentTimeSlot, activities: [])
        }

        // Filter for current weekday and time slot
        let slots = allSlots.filter {
            $0.weekday == currentWeekday && $0.timeSlot == currentTimeSlot
        }

        // Build widget activities (only incomplete)
        let activities = slots.compactMap { slot -> WidgetActivity? in
            guard let activity = slot.activity else { return nil }
            let isCompleted = activity.isCompleted(for: currentWeekday, timeSlot: currentTimeSlot)
            guard !isCompleted else { return nil }
            return WidgetActivity(
                id: activity.id,
                name: activity.name,
                icon: activity.icon,
                isCompleted: false
            )
        }.sorted { $0.name < $1.name }

        return SimpleEntry(date: date, timeSlot: currentTimeSlot, activities: activities)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let timeSlot: TimeSlot
    let activities: [WidgetActivity]
}

struct WidgetActivity: Identifiable {
    let id: UUID
    let name: String
    let icon: String
    let isCompleted: Bool
}

struct CurrentTimeSlotWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: entry.timeSlot.defaultIcon)
                    .foregroundStyle(entry.timeSlot.swiftUIColor)

                Text(entry.timeSlot.displayName())
                    .font(.headline)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 0)

            if entry.activities.isEmpty {
                ContentUnavailableView {
                    Label("No Activities", systemImage: "clock")
                }
                .scaleEffect(0.8)
            } else {
                // Activities list
                VStack(spacing: 0) {
                    ForEach(entry.activities.prefix(activityCount)) { activity in
                        WidgetActivityRow(activity: activity, timeSlot: entry.timeSlot)
                    }
                    Spacer()
                }
            }
        }
        .containerBackground(entry.timeSlot.swiftUIColor.opacity(0.1), for: .widget)
    }

    var activityCount: Int {
        switch family {
        case .accessoryCircular, .accessoryInline:
            return 1
        case .accessoryRectangular:
            return 2
        case .systemSmall:
            return 3
        case .systemMedium:
            return 5
        case .systemLarge:
            return 8
        default:
            return 3
        }
    }
}

struct WidgetActivityRow: View {
    let activity: WidgetActivity
    let timeSlot: TimeSlot

    var body: some View {
        HStack(spacing: 8) {
            if #available(iOS 17.0, *) {
                // Interactive button for iOS 17+
                Button(intent: CompleteActivityIntent(
                    activityID: activity.id.uuidString,
                    timeSlot: timeSlot.rawValue
                )) {
                    Image(systemName: activity.isCompleted ? "checkmark.circle.fill" : "circle")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(activity.isCompleted ? .white : .secondary, timeSlot.swiftUIColor)
                        .font(.system(size: 14))
                }
                .buttonStyle(.borderless)

                Text(activity.name)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
            } else {
                // Fallback for older iOS versions
                Image(systemName: activity.isCompleted ? "checkmark.circle.fill" : "circle")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(activity.isCompleted ? .white : .secondary, timeSlot.swiftUIColor)
                    .font(.system(size: 14))

                Text(activity.name)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

struct CurrentTimeSlotWidget: Widget {
    let kind: String = "CurrentTimeSlotWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CurrentTimeSlotWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Current Time Slot")
        .description("Shows your activities for the current time slot.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

#Preview(as: .systemSmall) {
    CurrentTimeSlotWidget()
} timeline: {
    SimpleEntry(date: Date(), timeSlot: .morning, activities: [])
}
