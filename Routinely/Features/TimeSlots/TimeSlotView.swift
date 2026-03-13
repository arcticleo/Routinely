//
//  TimeSlotView.swift
//  Routinely
//
//  Created by Michael Edlund on 2026-03-11.
//

import SwiftUI
import SwiftData

struct TimeSlotView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPreferences]

    @Query private var allActivityTimeSlots: [ActivityTimeSlot]

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
                $0.weekday == currentWeekday &&
                $0.timeSlot == timeSlot
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
                !activity.isCompleted(for: currentWeekday, timeSlot: timeSlot)
            }
        }
    }

    // Count of completed activities for this slot
    var completedCount: Int {
        activitiesForCurrentSlot.filter { $0.isCompleted(for: currentWeekday, timeSlot: timeSlot) }.count
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
                                ActivityCompletionRow(activity: activity, timeSlot: timeSlot, weekday: currentWeekday)
                            }
                        }
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
            }
            .onDisappear {
                stopTimer()
            }
        }
    }

    private func startTimer() {
        // Update every minute to check for time slot changes
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            let newTimeSlot = TimeSlot.current
            if newTimeSlot != timeSlot {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
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

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(spacing: 16) {
            CompletionButton(activity: activity, timeSlot: timeSlot, weekday: weekday)

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.name)
                    .font(.headline)

                if activity.isCompleted(for: weekday, timeSlot: timeSlot) {
                    Text("Completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: activity.icon)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(timeSlot.swiftUIColor.opacity(0.1))
        )
    }
}

#Preview {
    TimeSlotView()
        .modelContainer(for: [Activity.self, ActivityTimeSlot.self, Completion.self, UserPreferences.self], inMemory: true)
}
