import Foundation
import UserNotifications

enum ChatNotificationService {
    @MainActor private static var permissionRequested = false

    @MainActor
    static func requestPermissionOnce() {
        if !permissionRequested {
            permissionRequested = true
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) {
                _, _ in
            }
        }
    }

    static func postCompletion(sessionId: UUID, title: String, snippet: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = snippet
        content.sound = .default
        content.userInfo = ["sessionId": sessionId.uuidString]
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}

extension Notification.Name {
    static let notificationOpenSession = Notification.Name("cloude.notification.openSession")
}
