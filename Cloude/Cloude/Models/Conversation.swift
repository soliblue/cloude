//
//  Conversation.swift
//  Cloude
//
//  Conversation model and persistence
//

import Foundation
import Combine

struct Conversation: Codable, Identifiable {
    let id: UUID
    var name: String
    var sessionId: String?
    let createdAt: Date
    var lastMessageAt: Date
    var messages: [ChatMessage]
    var pendingMessages: [ChatMessage]

    init(name: String? = nil) {
        self.id = UUID()
        self.sessionId = nil
        self.createdAt = Date()
        self.lastMessageAt = Date()
        self.messages = []
        self.pendingMessages = []
        self.name = name ?? Self.generateName()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastMessageAt = try container.decode(Date.self, forKey: .lastMessageAt)
        messages = try container.decode([ChatMessage].self, forKey: .messages)
        pendingMessages = try container.decodeIfPresent([ChatMessage].self, forKey: .pendingMessages) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, sessionId, createdAt, lastMessageAt, messages, pendingMessages
    }

    private static func generateName() -> String {
        let adjectives = ["Quick", "Bright", "Swift", "Calm", "Bold", "Wise", "Kind", "Warm", "Cool", "Fresh"]
        let nouns = ["Chat", "Talk", "Session", "Thread", "Topic", "Query", "Task", "Project", "Idea", "Plan"]
        let adj = adjectives.randomElement() ?? "New"
        let noun = nouns.randomElement() ?? "Chat"
        return "\(adj) \(noun)"
    }
}

struct ToolCall: Codable {
    let name: String
    let input: String?
    let toolId: String
    let parentToolId: String?

    init(name: String, input: String?, toolId: String = UUID().uuidString, parentToolId: String? = nil) {
        self.name = name
        self.input = input
        self.toolId = toolId
        self.parentToolId = parentToolId
    }
}

struct ChatMessage: Codable, Identifiable {
    let id: UUID
    let isUser: Bool
    var text: String
    let timestamp: Date
    var toolCalls: [ToolCall]
    var durationMs: Int?
    var costUsd: Double?
    var isQueued: Bool
    var wasInterrupted: Bool
    var imageBase64: String?

    init(isUser: Bool, text: String, toolCalls: [ToolCall] = [], durationMs: Int? = nil, costUsd: Double? = nil, isQueued: Bool = false, wasInterrupted: Bool = false, imageBase64: String? = nil) {
        self.id = UUID()
        self.isUser = isUser
        self.text = text
        self.timestamp = Date()
        self.toolCalls = toolCalls
        self.durationMs = durationMs
        self.costUsd = costUsd
        self.isQueued = isQueued
        self.wasInterrupted = wasInterrupted
        self.imageBase64 = imageBase64
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        isUser = try container.decode(Bool.self, forKey: .isUser)
        text = try container.decode(String.self, forKey: .text)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        toolCalls = try container.decodeIfPresent([ToolCall].self, forKey: .toolCalls) ?? []
        durationMs = try container.decodeIfPresent(Int.self, forKey: .durationMs)
        costUsd = try container.decodeIfPresent(Double.self, forKey: .costUsd)
        isQueued = try container.decodeIfPresent(Bool.self, forKey: .isQueued) ?? false
        wasInterrupted = try container.decodeIfPresent(Bool.self, forKey: .wasInterrupted) ?? false
        imageBase64 = try container.decodeIfPresent(String.self, forKey: .imageBase64)
    }

    private enum CodingKeys: String, CodingKey {
        case id, isUser, text, timestamp, toolCalls, durationMs, costUsd, isQueued, wasInterrupted, imageBase64
    }
}

@MainActor
class ConversationStore: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?

    private let saveKey = "saved_conversations"

    init() {
        load()
    }

    func newConversation() -> Conversation {
        let conversation = Conversation()
        conversations.insert(conversation, at: 0)
        currentConversation = conversation
        save()
        return conversation
    }

    func select(_ conversation: Conversation) {
        currentConversation = conversation
    }

    func addMessage(_ message: ChatMessage, to conversation: Conversation) {
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        conversations[index].messages.append(message)
        conversations[index].lastMessageAt = Date()

        // Move to top
        let updated = conversations.remove(at: index)
        conversations.insert(updated, at: 0)

        if currentConversation?.id == conversation.id {
            currentConversation = conversations[0]
        }
        save()
    }

    func rename(_ conversation: Conversation, to name: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        conversations[index].name = name
        if currentConversation?.id == conversation.id {
            currentConversation = conversations[index]
        }
        save()
    }

    func updateSessionId(_ conversation: Conversation, sessionId: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        conversations[index].sessionId = sessionId
        if currentConversation?.id == conversation.id {
            currentConversation = conversations[index]
        }
        save()
    }

    func delete(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        if currentConversation?.id == conversation.id {
            currentConversation = conversations.first
        }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(conversations) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Conversation].self, from: data) {
            conversations = decoded
            currentConversation = conversations.first
        }
    }
}
