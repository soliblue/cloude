import Foundation
import UserNotifications

final class ChatNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ChatNotificationDelegate()
    private var pendingSessionId: UUID?

    func consumePending() -> UUID? {
        let id = pendingSessionId
        pendingSessionId = nil
        return id
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let idString = response.notification.request.content.userInfo["sessionId"] as? String,
            let sessionId = UUID(uuidString: idString)
        {
            pendingSessionId = sessionId
            NotificationCenter.default.post(name: .notificationOpenSession, object: sessionId)
        }
        completionHandler()
    }
}
