import Foundation
import SwiftData

@MainActor enum ChatPlanService {
    private static var submitting: Set<UUID> = []

    static func isCompletedPlan(_ message: ChatMessage, session: Session) -> Bool {
        message.sessionId == session.id && session.provider == .codex && message.role == .assistant
            && message.planIsComplete == true && message.state == .complete
            && !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func canImplement(_ message: ChatMessage, session: Session) -> Bool {
        if isCompletedPlan(message, session: session), !session.isStreaming, !session.remoteIsRunning,
            !session.isArchived, !submitting.contains(session.id), let endpoint = session.endpoint,
            !endpoint.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            (1...65535).contains(endpoint.port), ["http", "https"].contains(endpoint.transportScheme),
            let path = session.path, path.hasPrefix("/"), !path.contains("\0")
        {
            return true
        }
        return false
    }

    static func implement(_ message: ChatMessage, session: Session, context: ModelContext) -> Bool {
        if canImplement(message, session: session) {
            submitting.insert(session.id)
            let previousMode = session.permissionMode
            SessionActions.setPermissionMode(.standard, for: session.id, context: context)
            let accepted = ChatService.send(
                session: session, prompt: "Implement this selected plan:\n\n" + message.text, images: [],
                context: context)
            if !accepted { SessionActions.setPermissionMode(previousMode, for: session.id, context: context) }
            submitting.remove(session.id)
            return accepted
        }
        return false
    }
}
