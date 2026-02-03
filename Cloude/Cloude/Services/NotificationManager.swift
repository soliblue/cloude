import Foundation
import UserNotifications

struct NotificationManager {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func showCompletionNotification(preview: String) {
        let content = UNMutableNotificationContent()
        content.title = "Claude finished"
        content.body = String(preview.prefix(100))
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    static func showCustomNotification(title: String?, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title ?? "Cloude"
        content.body = String(body.prefix(200))
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
