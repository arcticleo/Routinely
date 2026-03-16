//
//  BadgeManager.swift
//  Routinely
//
//  Created by Assistant on 2026-03-14.
//

import Foundation
import SwiftData
import UserNotifications

/// Manages the app icon badge showing count of incomplete activities for current time slot
@MainActor
class BadgeManager {
    static let shared = BadgeManager()

    private init() {}

    /// Request permission to show badges
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .provisional]) { _, _ in }
    }

    /// Calculate and update badge for current time slot
    func updateBadge(in context: ModelContext) {
        let currentWeekday = Calendar.current.component(.weekday, from: Date())
        let currentTimeSlot = TimeSlot.current

        // Fetch activities for current slot - filter in memory since TimeSlot can't be used in predicate
        let descriptor = FetchDescriptor<ActivityTimeSlot>()

        guard let allSlots = try? context.fetch(descriptor) else {
            setBadge(0)
            return
        }
        let slots = allSlots.filter { $0.weekday == currentWeekday && $0.timeSlot == currentTimeSlot }

        let incompleteCount = slots.compactMap { $0.activity }.filter { activity in
            !activity.isCompleted(for: currentWeekday, timeSlot: currentTimeSlot)
        }.count

        setBadge(incompleteCount)
    }

    /// Set the app badge number
    private func setBadge(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }

    /// Clear the badge
    func clearBadge() {
        setBadge(0)
    }

    /// Schedule background notifications for all time slot boundaries
    func scheduleTimeSlotNotifications(in context: ModelContext) {
        let center = UNUserNotificationCenter.current()

        // Remove existing notifications
        center.removePendingNotificationRequests(withIdentifiers: timeSlotIdentifiers())

        // Schedule for each time slot boundary (00:00, 03:00, 06:00, 09:00, 12:00, 15:00, 18:00, 21:00)
        for hour in [0, 3, 6, 9, 12, 15, 18, 21] {
            scheduleNotification(for: hour, center: center, context: context)
        }
    }

    /// Schedule a notification for a specific hour
    private func scheduleNotification(for hour: Int, center: UNUserNotificationCenter, context: ModelContext) {
        let content = UNMutableNotificationContent()
        content.sound = nil // Silent

        // Calculate the activity count for this time slot
        let calendar = Calendar.current
        let now = Date()
        let currentWeekday = calendar.component(.weekday, from: now)

        // Find the TimeSlot for this hour
        guard let timeSlot = TimeSlot(rawValue: hour / 3) else { return }

        // Fetch activities for this slot - filter in memory since TimeSlot can't be used in predicate
        let descriptor = FetchDescriptor<ActivityTimeSlot>()

        var count = 0
        if let allSlots = try? context.fetch(descriptor) {
            let slots = allSlots.filter { $0.weekday == currentWeekday && $0.timeSlot == timeSlot }
            count = slots.compactMap { $0.activity }.filter { activity in
                !activity.isCompleted(for: currentWeekday, timeSlot: timeSlot)
            }.count
        }

        content.badge = NSNumber(value: count)

        // Create trigger for this hour
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = 0
        dateComponents.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let identifier = "badge-update-\(hour)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { _ in }
    }

    /// Generate identifiers for all time slot notifications
    private func timeSlotIdentifiers() -> [String] {
        [0, 3, 6, 9, 12, 15, 18, 21].map { "badge-update-\($0)" }
    }

    /// Cancel all scheduled notifications
    func cancelNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: timeSlotIdentifiers())
    }
}
