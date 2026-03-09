import Foundation
import Combine
import CloudeShared

extension EnvironmentConnection {
    func handleRenameConversation(_ mgr: ConnectionManager, conversationId: String, name: String) {
        if let id = UUID(uuidString: conversationId) {
            mgr.events.send(.renameConversation(conversationId: id, name: name))
        }
    }

    func handleSetConversationSymbol(_ mgr: ConnectionManager, conversationId: String, symbol: String?) {
        if let id = UUID(uuidString: conversationId) {
            mgr.events.send(.setConversationSymbol(conversationId: id, symbol: symbol))
        }
    }

    func handleDeleteConversation(_ mgr: ConnectionManager, conversationId: String) {
        if let id = UUID(uuidString: conversationId) {
            mgr.events.send(.deleteConversation(conversationId: id))
        }
    }

    func handleSwitchConversation(_ mgr: ConnectionManager, conversationId: String) {
        if let id = UUID(uuidString: conversationId) {
            mgr.events.send(.switchConversation(conversationId: id))
        }
    }

    func handleQuestion(_ mgr: ConnectionManager, questions: [Question], conversationId: String?) {
        mgr.events.send(.question(questions: questions, conversationId: conversationId.flatMap { UUID(uuidString: $0) }))
    }

    func handleScreenshot(_ mgr: ConnectionManager, conversationId: String?) {
        mgr.events.send(.screenshot(conversationId: conversationId.flatMap { UUID(uuidString: $0) }))
    }

    func handleNameSuggestion(_ mgr: ConnectionManager, name: String, symbol: String?, conversationId: String) {
        if let id = UUID(uuidString: conversationId) {
            mgr.events.send(.renameConversation(conversationId: id, name: name))
            if let s = symbol {
                mgr.events.send(.setConversationSymbol(conversationId: id, symbol: s))
            }
        }
    }

    func handleTeamCreated(_ mgr: ConnectionManager, teamName: String, conversationId: String?) {
        if let id = targetConversationId(from: conversationId) { mgr.output(for: id).teamName = teamName }
    }

    func handleTeammateSpawned(_ mgr: ConnectionManager, teammate: TeammateInfo, conversationId: String?) {
        if let id = targetConversationId(from: conversationId) { mgr.output(for: id).teammates.append(teammate) }
    }

    func handleTeamDeleted(_ mgr: ConnectionManager, conversationId: String?) {
        if let id = targetConversationId(from: conversationId) {
            let o = mgr.output(for: id)
            if let teamName = o.teamName, !o.teammates.isEmpty {
                o.teamSnapshot = (name: teamName, members: o.teammates)
            }
            o.teamName = nil
            o.teammates = []
        }
    }

    func handleTeammateUpdate(_ mgr: ConnectionManager, teammateId: String, status: TeammateStatus?, lastMessage: String?, lastMessageAt: Date?, conversationId: String?) {
        guard let convId = targetConversationId(from: conversationId) else { return }
        let out = mgr.output(for: convId)
        if let idx = out.teammates.firstIndex(where: { $0.id == teammateId || $0.name == teammateId }) {
            if let status { out.teammates[idx].status = status }
            if let msg = lastMessage {
                let ts = lastMessageAt ?? Date()
                out.teammates[idx].lastMessage = msg
                out.teammates[idx].lastMessageAt = ts
                out.teammates[idx].appendMessage(msg, at: ts)
            } else if let ts = lastMessageAt {
                out.teammates[idx].lastMessageAt = ts
            }
        }
    }
}
