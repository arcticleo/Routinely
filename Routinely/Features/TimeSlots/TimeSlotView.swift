//
//  TimeSlotView.swift
//  Routinely
//
//  Created by Michael Edlund on 2026-03-11.
//

import SwiftUI
import SwiftData
import UserNotifications
import WidgetKit

struct TimeSlotView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var preferences: [UserPreferences]

    @State private var allActivityTimeSlots: [ActivityTimeSlot] = []
    @State private var completedActivityIDs: Set<UUID> = []
    @State private var timeSlot: TimeSlot = TimeSlot.current
    @State private var showCompleted = false
    @State private var timer: Timer? = nil

    // Current weekday (1 = Sunday, 2 = Monday, ... 7 = Saturday)
    private var currentWeekday: Int {
        Calendar.current.component(.weekday, from: Date())
    }

    // Activities scheduled for current weekday + current time slot
    var activitiesForCurrentSlot: [Activity] {
        allActivityTimeSlots
            .filter {
                // Check and clear expired punts
                $0.checkAndClearExpiredPunt()
                
                // Match on weekday and effective time slot
                return $0.weekday == currentWeekday &&
                       $0.effectiveTimeSlot() == timeSlot
            }
            .compactMap { $0.activity }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    // Filtered activities based on showCompleted toggle
    var visibleActivities: [Activity] {
        if showCompleted {
            return activitiesForCurrentSlot
        } else {
            return activitiesForCurrentSlot.filter { activity in
                !completedActivityIDs.contains(activity.id)
            }
        }
    }

    // Count of completed activities for this slot
    var completedCount: Int {
        activitiesForCurrentSlot.filter { completedActivityIDs.contains($0.id) }.count
    }

    var totalCount: Int {
        activitiesForCurrentSlot.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    TimeSlotHeader(timeSlot: timeSlot, weekday: currentWeekday)

                    if activitiesForCurrentSlot.isEmpty {
                        ContentUnavailableView {
                            Label("No Activities", systemImage: timeSlot.defaultIcon)
                        } description: {
                            Text("No activities scheduled for this time slot today.")
                        } actions: {
                            NavigationLink(destination: ActivityListView()) {
                                Text("Manage Activities")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 40)
                    } else if visibleActivities.isEmpty && !showCompleted {
                        // All activities completed, show completion message
                        ContentUnavailableView {
                            Label("All Done!", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(visibleActivities) { activity in
                                ActivityCompletionRow(
                                    activity: activity,
                                    timeSlot: timeSlot,
                                    weekday: currentWeekday,
                                    isCompleted: completedActivityIDs.contains(activity.id),
                                    onToggle: fetchActivityTimeSlots
                                )
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                            }
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: visibleActivities.map { $0.id })
                        .padding(.horizontal)
                        .padding(.top, 16)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Current")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if totalCount > 0 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showCompleted.toggle()
                        } label: {
                            Label(showCompleted ? "Hide Completed" : "Show All",
                                  systemImage: showCompleted ? "eye.slash" : "eye")
                        }
                    }
                }
            }
            .onAppear {
                startTimer()
                fetchActivityTimeSlots()
                BadgeManager.shared.requestNotificationPermission()
                BadgeManager.shared.updateBadge(in: modelContext)
            }
            .onDisappear {
                stopTimer()
            }
            .onChange(of: visibleActivities.count) { _, _ in
                BadgeManager.shared.updateBadge(in: modelContext)
            }
            .onChange(of: timeSlot) { _, _ in
                BadgeManager.shared.updateBadge(in: modelContext)
                WidgetCenter.shared.reloadAllTimelines()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    BadgeManager.shared.updateBadge(in: modelContext)
                    BadgeManager.shared.scheduleTimeSlotNotifications(in: modelContext)
                    WidgetCenter.shared.reloadAllTimelines()
                } else if newPhase == .active {
                    // Re-fetch to pick up changes from widget
                    fetchActivityTimeSlots()
                    BadgeManager.shared.updateBadge(in: modelContext)
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
        }
    }

    private func startTimer() {
        // Update every minute to check for time slot changes
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            let newTimeSlot = TimeSlot.current
            if newTimeSlot != timeSlot {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    timeSlot = newTimeSlot
                }
            }
        }
        // Also update immediately
        timeSlot = TimeSlot.current
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func fetchActivityTimeSlots() {
        // Fetch time slots
        let slotDescriptor = FetchDescriptor<ActivityTimeSlot>()
        allActivityTimeSlots = (try? modelContext.fetch(slotDescriptor)) ?? []
        
        // Clear expired punts
        clearExpiredPunts()

        // Fetch completions directly for current week
        let calendar = Calendar.current
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!

        let completionDescriptor = FetchDescriptor<Completion>(
            predicate: #Predicate { completion in
                completion.completedAt >= weekStart && completion.completedAt < weekEnd
            }
        )
        let completions = (try? modelContext.fetch(completionDescriptor)) ?? []
        completedActivityIDs = Set(completions.filter {
            $0.weekday == currentWeekday &&
            $0.timeSlot == timeSlot
        }.compactMap { $0.activity?.id })
    }
    
    private func clearExpiredPunts() {
        // Check all activity time slots and clear expired punts
        for slot in allActivityTimeSlots {
            slot.checkAndClearExpiredPunt()
        }
        // Save any changes
        try? modelContext.save()
    }
}

// MARK: - Time Slot Header
struct TimeSlotHeader: View {
    let timeSlot: TimeSlot
    let weekday: Int

    private var weekdayName: String {
        Calendar.current.weekdaySymbols[weekday - 1]
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: timeSlot.defaultIcon)
                    .font(.system(size: 48))
                    .foregroundStyle(timeSlot.swiftUIColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(timeSlot.displayName())
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(weekdayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(timeSlot.swiftUIColor.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(timeSlot.swiftUIColor.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.top)
    }
}

// MARK: - Activity Completion Row
struct ActivityCompletionRow: View {
    let activity: Activity
    let timeSlot: TimeSlot
    let weekday: Int  // 1 = Sunday, 2 = Monday, ... 7 = Saturday
    let isCompleted: Bool
    var onToggle: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext

    private var nextTimeSlot: TimeSlot {
        let nextRawValue = (timeSlot.rawValue + 1) % TimeSlot.allCases.count
        return TimeSlot(rawValue: nextRawValue) ?? .midnightTo3am
    }

    var body: some View {
        HStack(spacing: 16) {
            CompletionButton(activity: activity, timeSlot: timeSlot, weekday: weekday, onToggle: onToggle)

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.name)
                    .font(.headline)

                if isCompleted {
                    Text("Completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: activity.icon)
                .font(.title3)
                .foregroundStyle(activity.swiftUIColor)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(timeSlot.swiftUIColor.opacity(0.1))
        )
        .contextMenu {
            Button {
                puntToNextTimeSlot()
            } label: {
                Label("Punt", systemImage: "arrow.forward")
            }
        }
    }

    private func puntToNextTimeSlot() {
        // Find the ActivityTimeSlot for this activity/weekday/timeSlot combo
        let descriptor = FetchDescriptor<ActivityTimeSlot>()
        guard let allSlots = try? modelContext.fetch(descriptor) else { return }
        
        // Find the matching slot
        if let slot = allSlots.first(where: { 
            $0.activity?.id == activity.id && 
            $0.weekday == weekday && 
            $0.timeSlot == timeSlot 
        }) {
            // Punt it to the next time slot with animation
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                slot.punt(to: nextTimeSlot)
                
                // Save the context
                try? modelContext.save()
                
                // Trigger refresh
                onToggle?()
            }
        }
    }
}

#Preview {
    TimeSlotView()
        .modelContainer(for: [Activity.self, ActivityTimeSlot.self, Completion.self, UserPreferences.self], inMemory: true)
}
