import Foundation

enum ChatNotificationService {
    static var notifications: [(UUID, String, String)] = []
    static func postCompletion(sessionId: UUID, title: String, snippet: String) {
        notifications.append((sessionId, title, snippet))
    }
}
