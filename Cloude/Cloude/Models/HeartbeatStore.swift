//
//  HeartbeatStore.swift
//  Cloude
//

import Foundation
import Combine

@MainActor
class HeartbeatStore: ObservableObject {
    @Published var intervalMinutes: Int?
    @Published var unreadCount: Int = 0
    @Published var conversation: Conversation
    @Published var isRunning = false
    @Published var currentOutput = ""
    @Published var lastTriggeredAt: Date?

    private let storageKey = "heartbeatConversation"
    private let lastTriggeredKey = "heartbeatLastTriggered"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(Conversation.self, from: data) {
            conversation = saved
        } else {
            conversation = Conversation(name: "Heartbeat", symbol: "heart.fill")
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

    func handleConfig(intervalMinutes: Int?, unreadCount: Int, sessionId: String?) {
        print("[HeartbeatStore] handleConfig: interval=\(String(describing: intervalMinutes)), unread=\(unreadCount), sessionId=\(String(describing: sessionId))")
        self.intervalMinutes = intervalMinutes
        self.unreadCount = unreadCount
        if let sid = sessionId {
            self.conversation.sessionId = sid
            save()
        }
    }

    func handleOutput(text: String) {
        currentOutput += text
        isRunning = true
        if lastTriggeredAt == nil {
            recordTrigger()
        }
    }

    func recordTrigger() {
        lastTriggeredAt = Date()
        UserDefaults.standard.set(lastTriggeredAt, forKey: lastTriggeredKey)
    }

    func handleComplete(message: String) {
        print("[HeartbeatStore] handleComplete: '\(message.prefix(30))...'")
        if !message.isEmpty {
            let chatMessage = ChatMessage(isUser: false, text: message)
            conversation.messages.append(chatMessage)
            conversation.lastMessageAt = Date()
            save()
        }
        currentOutput = ""
        isRunning = false
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
