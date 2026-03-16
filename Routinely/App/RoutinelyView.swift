//
//  RoutinelyView.swift
//  Routinely
//
//  Created by Michael Edlund on 2026-03-11.
//

import SwiftUI
import SwiftData

struct RoutinelyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var preferences: [UserPreferences]

    var body: some View {
        TabView {
            // Current Time Slot Tab - manages its own time slot
            TimeSlotView()
                .tabItem {
                    Label("Current", systemImage: "clock")
                }

            // Activities Tab
            ActivityListView()
                .tabItem {
                    Label("Activities", systemImage: "list.bullet")
                }
        }
        .onAppear {
            ensureUserPreferencesExist()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                // Refresh to pick up changes from widget
                BadgeManager.shared.updateBadge(in: modelContext)
            }
        }
    }

    private func ensureUserPreferencesExist() {
        if preferences.isEmpty {
            let prefs = UserPreferences()
            modelContext.insert(prefs)
            try? modelContext.save()
        }
    }
}

// MARK: - iPadOS/macOS NavigationSplitView variant (for future use)
/*
struct RoutinelySplitView: View {
    @State private var selectedTimeSlot: TimeSlot? = TimeSlot.current

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedTimeSlot: $selectedTimeSlot)
        } detail: {
            if let timeSlot = selectedTimeSlot {
                TimeSlotView()
            } else {
                ContentUnavailableView("Select a Time Slot", systemImage: "clock")
            }
        }
    }
}
*/

#Preview {
    RoutinelyView()
        .modelContainer(for: [Activity.self, ActivityTimeSlot.self, Completion.self, UserPreferences.self], inMemory: true)
}
