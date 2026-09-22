import Foundation
import UserNotifications

/// Thin wrapper over UNUserNotificationCenter so feature code never talks to the
/// system framework directly. One pending request per todo, keyed by its UUID.
enum ReminderScheduler {
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func schedule(for item: TodoItem) {
        guard let remindAt = item.remindAt, remindAt > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = item.title
        if !item.note.isEmpty {
            content.body = item.note
        }
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: remindAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancel(for item: TodoItem) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [item.id.uuidString])
    }

    /// Keeps pending requests in sync after any mutation of the reminder.
    static func sync(_ item: TodoItem) {
        cancel(for: item)
        if !item.isDone {
            schedule(for: item)
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
