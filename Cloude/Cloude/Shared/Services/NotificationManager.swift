import Foundation
import UserNotifications

struct NotificationManager {
    static func requestPermission() {
        if ProcessInfo.processInfo.environment["CLOUDE_SKIP_PROMPTS"] != "1" {
            UNUserNotificationCenter.current().requestAuthorization(options: [
                .alert, .sound, .badge,
            ]) { _, _ in }
        }
    }

    static func showNotification(title: String?, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title ?? "Cloude"
        content.body = String(body.prefix(200))
        content.sound = .default

        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
