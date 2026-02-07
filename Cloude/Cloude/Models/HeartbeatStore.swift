import Foundation
import Combine
import CloudeShared

@MainActor
class HeartbeatStore: ObservableObject {
    @Published var intervalMinutes: Int?
    @Published var unreadCount: Int = 0
    @Published var conversation: Conversation
    @Published var lastTriggeredAt: Date?

    private let storageKey = "heartbeatConversation"
    private let lastTriggeredKey = "heartbeatLastTriggered"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(Conversation.self, from: data) {
            conversation = Conversation(
                name: saved.name,
                symbol: saved.symbol,
                id: Heartbeat.conversationId,
                sessionId: Heartbeat.sessionId
            )
            conversation.messages = saved.messages
            conversation.pendingMessages = saved.pendingMessages
            conversation.lastMessageAt = saved.lastMessageAt
        } else {
            conversation = Conversation(
                name: "Heartbeat",
                symbol: "heart.fill",
                id: Heartbeat.conversationId,
                sessionId: Heartbeat.sessionId
            )
        }
        if let timestamp = UserDefaults.standard.object(forKey: lastTriggeredKey) as? Date {
            lastTriggeredAt = timestamp
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(conversation) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func handleConfig(intervalMinutes: Int?, unreadCount: Int) {
        print("[HeartbeatStore] handleConfig: interval=\(String(describing: intervalMinutes)), unread=\(unreadCount)")
        self.intervalMinutes = intervalMinutes
        self.unreadCount = unreadCount
    }

    func recordTrigger() {
        lastTriggeredAt = Date()
        UserDefaults.standard.set(lastTriggeredAt, forKey: lastTriggeredKey)
    }

    func markRead() {
        unreadCount = 0
    }

    var intervalDisplayText: String {
        guard let minutes = intervalMinutes else { return "Off" }
        switch minutes {
        case 5: return "5min"
        case 10: return "10min"
        case 30: return "30min"
        case 60: return "1hr"
        case 120: return "2hr"
        case 240: return "4hr"
        case 480: return "8hr"
        case 1440: return "1 day"
        default: return "\(minutes)min"
        }
    }

    var nextHeartbeatAt: Date? {
        guard let interval = intervalMinutes, interval > 0,
              let lastTriggered = lastTriggeredAt else { return nil }
        return lastTriggered.addingTimeInterval(TimeInterval(interval * 60))
    }

    var lastTriggeredDisplayText: String {
        guard let date = lastTriggeredAt else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var nextHeartbeatDisplayText: String? {
        guard let next = nextHeartbeatAt else { return nil }
        if next <= Date() { return "Soon" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: next, relativeTo: Date())
    }
}
