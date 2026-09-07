import Foundation
import UserNotifications

final class ChatNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ChatNotificationDelegate()
    private var pendingRoute: ChatNotificationRoute?

    func consumePending() -> ChatNotificationRoute? {
        let route = pendingRoute
        pendingRoute = nil
        return route
    }

    func receive(userInfo: [AnyHashable: Any]) {
        if let route = ChatNotificationRoute(userInfo: userInfo) {
            pendingRoute = route
            NotificationCenter.default.post(name: .notificationOpenSession, object: route)
        }
    }

    static func presentationOptions(for userInfo: [AnyHashable: Any]) -> UNNotificationPresentationOptions {
        if case .schedule = ChatNotificationRoute(userInfo: userInfo) {
            return [.banner, .list, .sound]
        }
        return []
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler(Self.presentationOptions(for: notification.request.content.userInfo))
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier != UNNotificationDismissActionIdentifier {
            receive(userInfo: response.notification.request.content.userInfo)
        }
        completionHandler()
    }
}
