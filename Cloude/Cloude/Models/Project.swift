//
//  Project.swift
//  Cloude
//
//  Project model
//

import Foundation

struct Project: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var rootDirectory: String
    var conversations: [Conversation]
    let createdAt: Date
    var lastMessageAt: Date

    init(name: String, rootDirectory: String = "") {
        self.id = UUID()
        self.name = name
        self.rootDirectory = rootDirectory
        self.conversations = []
        self.createdAt = Date()
        self.lastMessageAt = Date()
    }

    mutating func addConversation(_ conversation: Conversation) {
        conversations.insert(conversation, at: 0)
        lastMessageAt = Date()
    }

    mutating func updateConversation(_ conversation: Conversation) {
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        conversations[index] = conversation
        lastMessageAt = Date()
    }

    mutating func removeConversation(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
    }

    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
