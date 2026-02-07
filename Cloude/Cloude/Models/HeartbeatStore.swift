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
        if let saved = UserDefaults.standard.codable(Conversation.self, forKey: storageKey) {
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
        UserDefaults.standard.setCodable(conversation, forKey: storageKey)
    }

    func handleConfig(intervalMinutes: Int?, unreadCount: Int) {
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

}
