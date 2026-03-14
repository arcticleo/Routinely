//
//  ActivityListView.swift
//  Routinely
//
//  Created by Michael Edlund on 2026-03-11.
//

import SwiftUI
import SwiftData

struct ActivityListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Activity.sortOrder) private var activities: [Activity]

    @State private var showingAddActivity = false
    @State private var editingActivity: Activity?

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    ForEach(activities) { activity in
                        ActivityRowView(activity: activity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingActivity = activity
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    deleteActivity(activity)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    editingActivity = activity
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.indigo)
                            }
                    }
                    .onMove(perform: moveActivities)
                }

                if activities.isEmpty {
                    ContentUnavailableView {
                        Label("No Activities", systemImage: "list.bullet")
                    } description: {
                        Text("Add your first activity or populate with samples.")
                    } actions: {
                        Button {
                            Activity.addSamples(to: modelContext)
                        } label: {
                            Label("Add Sample Activities", systemImage: "wand.and.stars")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Activities")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddActivity = true
                    } label: {
                        Label("Add Activity", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddActivity) {
                ActivityFormView(activity: nil)
            }
            .sheet(item: $editingActivity) { activity in
                ActivityFormView(activity: activity)
            }
        }
    }

    private func deleteActivity(_ activity: Activity) {
        modelContext.delete(activity)
        try? modelContext.save()
    }

    private func moveActivities(from source: IndexSet, to destination: Int) {
        var reordered = activities
        reordered.move(fromOffsets: source, toOffset: destination)

        for (index, activity) in reordered.enumerated() {
            activity.sortOrder = index
        }

        try? modelContext.save()
    }
}

#Preview {
    ActivityListView()
        .modelContainer(for: [Activity.self, ActivityTimeSlot.self, Completion.self, UserPreferences.self], inMemory: true)
}
