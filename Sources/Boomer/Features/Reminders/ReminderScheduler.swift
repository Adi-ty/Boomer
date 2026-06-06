import Foundation
import UserNotifications

/// Thin wrapper around `UNUserNotificationCenter` for reminder + focus
/// notifications. Authorization is requested via `PermissionsManager`.
@MainActor
enum ReminderScheduler {
    static func schedule(title: String, at date: Date, id: String) {
        let content = UNMutableNotificationContent()
        content.title = "Boomer"
        content.body = title
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(date.timeIntervalSinceNow, 1), repeats: false
        )
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func fireNow(title: String) {
        let content = UNMutableNotificationContent()
        content.title = "Boomer"
        content.body = title
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancel(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
