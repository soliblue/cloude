import Foundation
import Combine
import CloudeShared

@MainActor
class HeartbeatStore: ObservableObject {
    @Published var intervalMinutes: Int?
    @Published var unreadCount: Int = 0
    @Published var conversation: Conversation
    @Published var lastTriggeredAt: Date?

    private let legacyStorageKey = "heartbeatConversation"
    private let lastTriggeredKey = "heartbeatLastTriggered"

    private static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("heartbeat.json")
    }

    init() {
        if let legacy = UserDefaults.standard.codable(Conversation.self, forKey: legacyStorageKey) {
            conversation = Conversation(
                name: legacy.name,
                symbol: legacy.symbol,
                id: Heartbeat.conversationId,
                sessionId: Heartbeat.sessionId
            )
            conversation.messages = legacy.messages
            conversation.pendingMessages = legacy.pendingMessages
            conversation.lastMessageAt = legacy.lastMessageAt
            UserDefaults.standard.removeObject(forKey: legacyStorageKey)
            if let data = try? JSONEncoder().encode(conversation) {
                try? data.write(to: Self.fileURL)
            }
        } else if let data = try? Data(contentsOf: Self.fileURL),
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
            try? data.write(to: Self.fileURL)
        }
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
