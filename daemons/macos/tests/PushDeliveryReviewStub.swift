final class PushDelivery {
    static let shared = PushDelivery()
    func enqueueNotification(sessionId: String, title: String, body: String, kind: String, eventId: String) {}
    func cancelNotification(eventId: String) {}
}
