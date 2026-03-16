//
//  NotificationScheduler.swift
//  Routinely
//
//  Created by Assistant on 2026-03-14.
//

import Foundation
import UserNotifications
import SwiftData

/// Schedules background notifications to update the badge at each time slot boundary
@MainActor
class NotificationScheduler {
    static let shared = NotificationScheduler()

    private init() {}

    /// Request notification authorization for badge updates
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .provisional]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            } else {
                print("Notification authorization granted: \(granted)")
                if granted {
                    Task { @MainActor in
                        self.scheduleBadgeUpdates()
                    }
                }
            }
        }
    }

    /// Schedule badge update notifications for all time slot boundaries
    func scheduleBadgeUpdates() {
        let center = UNUserNotificationCenter.current()

        // Remove existing badge notifications
        center.removePendingNotificationRequests(withIdentifiers: timeSlotIdentifiers())

        // Schedule for each time slot boundary
        for timeSlot in TimeSlot.allCases {
            scheduleBadgeUpdate(for: timeSlot, center: center)
        }
    }

    /// Schedule a single badge update notification for a time slot
    private func scheduleBadgeUpdate(for timeSlot: TimeSlot, center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.badge = NSNumber(value: calculateActivityCount(for: timeSlot))
        content.sound = nil // Silent
        content.title = "" // No title
        content.body = "" // No body

        // Create trigger for this time slot
        var dateComponents = DateComponents()
        dateComponents.hour = timeSlot.startHour
        dateComponents.minute = 0
        dateComponents.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let identifier = "badge-update-\(timeSlot.rawValue)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule badge update for \(timeSlot.displayName()): \(error)")
            } else {
                print("Scheduled badge update for \(timeSlot.displayName())")
            }
        }
    }

    /// Calculate the number of incomplete activities for a given time slot
    private func calculateActivityCount(for timeSlot: TimeSlot) -> Int {
        // This is a placeholder - the actual count will be calculated when the notification fires
        // For now, return 0 as the badge will be updated when app opens
        return 0
    }

    /// Generate identifiers for all time slot notifications
    private func timeSlotIdentifiers() -> [String] {
        TimeSlot.allCases.map { "badge-update-\($0.rawValue)" }
    }

    /// Cancel all scheduled badge notifications
    func cancelBadgeUpdates() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: timeSlotIdentifiers())
    }
}

// MARK: - Badge Update Handler
extension NotificationScheduler {
    /// Update the badge count for the current time slot
    /// This is called when a notification fires or when app becomes active
    static func updateBadgeForCurrentSlot(in context: ModelContext) {
        let currentWeekday = Calendar.current.component(.weekday, from: Date())
        let currentTimeSlot = TimeSlot.current

        let descriptor = FetchDescriptor<ActivityTimeSlot>(
            predicate: #Predicate { slot in
                slot.weekday == currentWeekday && slot.timeSlot == currentTimeSlot
            }
        )

        guard let slots = try? context.fetch(descriptor) else {
            UNUserNotificationCenter.current().setBadgeCount(0)
            return
        }

        let incompleteCount = slots.compactMap { $0.activity }.filter { activity in
            !activity.isCompleted(for: currentWeekday, timeSlot: currentTimeSlot)
        }.count

        UNUserNotificationCenter.current().setBadgeCount(incompleteCount)
    }
}
