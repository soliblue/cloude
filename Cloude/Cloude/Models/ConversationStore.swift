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
        if let data = try? JSONEncoder().encode(conversations) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
        if let triggeredAt = heartbeatConfig.lastTriggeredAt {
            UserDefaults.standard.set(triggeredAt, forKey: heartbeatTriggeredKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Conversation].self, from: data) {
            conversations = decoded
        }

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
