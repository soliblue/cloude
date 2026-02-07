import Foundation
import Combine
import CloudeShared

struct PendingQuestion: Equatable {
    let conversationId: UUID
    let questions: [Question]
}

struct HeartbeatConfig {
    var intervalMinutes: Int?
    var unreadCount: Int = 0
    var lastTriggeredAt: Date?

    static let intervalOptions: [(label: String, minutes: Int)] = [
        ("Off", 0),
        ("5 min", 5),
        ("10 min", 10),
        ("30 min", 30),
        ("1 hour", 60),
        ("2 hours", 120),
        ("4 hours", 240),
        ("8 hours", 480),
        ("1 day", 1440)
    ]

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
        return DateFormatters.relativeTime(date)
    }

    var nextHeartbeatDisplayText: String? {
        guard let next = nextHeartbeatAt else { return nil }
        if next <= Date() { return "Soon" }
        return DateFormatters.relativeTime(next)
    }
}

@MainActor
class ConversationStore: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?
    @Published var pendingQuestion: PendingQuestion?
    @Published var questionInputFocused: Bool = false
    @Published var heartbeatConfig = HeartbeatConfig()

    private let saveKey = "saved_conversations_v2"
    private let heartbeatTriggeredKey = "heartbeatLastTriggered"

    var heartbeatConversation: Conversation {
        conversations.first(where: { $0.id == Heartbeat.conversationId })
            ?? Conversation(name: "Heartbeat", symbol: "heart.fill", id: Heartbeat.conversationId, sessionId: Heartbeat.sessionId)
    }

    func isHeartbeat(_ id: UUID) -> Bool {
        id == Heartbeat.conversationId
    }

    var listableConversations: [Conversation] {
        conversations.filter { $0.id != Heartbeat.conversationId }
    }

    func conversation(withId id: UUID) -> Conversation? {
        conversations.first { $0.id == id }
    }

    var conversationsByDirectory: [(directory: String, conversations: [Conversation])] {
        let grouped = Dictionary(grouping: listableConversations) { conv in
            conv.workingDirectory ?? ""
        }
        return grouped.map { dir, convs in
            (directory: dir, conversations: convs.sorted { $0.lastMessageAt > $1.lastMessageAt })
        }.sorted { lhs, rhs in
            let lhsDate = lhs.conversations.first?.lastMessageAt ?? .distantPast
            let rhsDate = rhs.conversations.first?.lastMessageAt ?? .distantPast
            return lhsDate > rhsDate
        }
    }

    var uniqueWorkingDirectories: [String] {
        Array(Set(listableConversations.compactMap { $0.workingDirectory })).filter { !$0.isEmpty }
    }

    init() {
        load()
    }

    func save() {
        UserDefaults.standard.setCodable(conversations, forKey: saveKey)
        if let triggeredAt = heartbeatConfig.lastTriggeredAt {
            UserDefaults.standard.set(triggeredAt, forKey: heartbeatTriggeredKey)
        }
    }

    private func load() {
        conversations = UserDefaults.standard.codable([Conversation].self, forKey: saveKey, default: [])

        ensureHeartbeatExists()
        currentConversation = listableConversations.first

        if let timestamp = UserDefaults.standard.object(forKey: heartbeatTriggeredKey) as? Date {
            heartbeatConfig.lastTriggeredAt = timestamp
        }
    }

    private func ensureHeartbeatExists() {
        if !conversations.contains(where: { $0.id == Heartbeat.conversationId }) {
            conversations.append(Conversation(
                name: "Heartbeat",
                symbol: "heart.fill",
                id: Heartbeat.conversationId,
                sessionId: Heartbeat.sessionId
            ))
        }
    }

    func handleHeartbeatConfig(intervalMinutes: Int?, unreadCount: Int) {
        heartbeatConfig.intervalMinutes = intervalMinutes
        heartbeatConfig.unreadCount = unreadCount
    }

    func recordHeartbeatTrigger() {
        heartbeatConfig.lastTriggeredAt = Date()
        UserDefaults.standard.set(heartbeatConfig.lastTriggeredAt, forKey: heartbeatTriggeredKey)
    }

    func markHeartbeatRead() {
        heartbeatConfig.unreadCount = 0
    }
}
