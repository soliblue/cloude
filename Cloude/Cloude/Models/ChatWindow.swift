//
//  ChatWindow.swift
//  Cloude

import Foundation

enum WindowType: String, CaseIterable, Codable {
    case chat
    case files
    case gitChanges

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .files: return "folder"
        case .gitChanges: return "arrow.triangle.branch"
        }
    }

    var label: String {
        switch self {
        case .chat: return "Chat"
        case .files: return "Files"
        case .gitChanges: return "Changes"
        }
    }
}

struct ChatWindow: Identifiable, Codable {
    let id: UUID
    var type: WindowType
    var conversationId: UUID?
    var projectId: UUID?

    init(id: UUID = UUID(), type: WindowType = .chat, conversationId: UUID? = nil, projectId: UUID? = nil) {
        self.id = id
        self.type = type
        self.conversationId = conversationId
        self.projectId = projectId
    }
}
