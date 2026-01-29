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

    init(name: String? = nil) {
        self.id = UUID()
        self.sessionId = nil
        self.createdAt = Date()
        self.lastMessageAt = Date()
        self.messages = []
        self.name = name ?? Self.generateName()
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
    let text: String
    let timestamp: Date
    var toolCalls: [ToolCall]
    var durationMs: Int?
    var costUsd: Double?

    init(isUser: Bool, text: String, toolCalls: [ToolCall] = [], durationMs: Int? = nil, costUsd: Double? = nil) {
        self.id = UUID()
        self.isUser = isUser
        self.text = text
        self.timestamp = Date()
        self.toolCalls = toolCalls
        self.durationMs = durationMs
        self.costUsd = costUsd
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
