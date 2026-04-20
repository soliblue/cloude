import Foundation
import CloudeShared

@MainActor
final class EnvironmentConversationRuntime {
    let environmentId: UUID

    var send: ((ClientMessage) -> Void)? {
        didSet {
            for conversation in conversations.values {
                conversation.send = send
            }
        }
    }
    var emitEvent: ((ConnectionEvent) -> Void)?
    var resolveDefaultWorkingDirectory: () -> String? = { nil } {
        didSet {
            for conversation in conversations.values {
                conversation.resolveDefaultWorkingDirectory = resolveDefaultWorkingDirectory
            }
        }
    }
    var interruptedSessions: [String: InterruptedSession] = [:]
    var conversations: [UUID: ConversationAPI] = [:]

    init(environmentId: UUID) {
        self.environmentId = environmentId
    }

    var runningOutputs: [(conversationId: UUID, output: ConversationOutput)] {
        conversations.compactMap { (conversationId, conversation) in
            conversation.output.phase != .idle ? (conversationId, conversation.output) : nil
        }
    }

    var hasRunningOutputs: Bool {
        conversations.values.contains { $0.output.phase != .idle }
    }

    func conversation(for conversationId: UUID) -> ConversationAPI {
        if let existing = conversations[conversationId] {
            return existing
        }
        let new = ConversationAPI(environmentId: environmentId, conversationId: conversationId)
        new.send = send
        new.resolveDefaultWorkingDirectory = resolveDefaultWorkingDirectory
        new.trackInterruptedSession = { [weak self] sessionId, messageId in
            self?.interruptedSessions[sessionId] = InterruptedSession(conversationId: conversationId, messageId: messageId)
        }
        new.hasInterruptedSession = { [weak self] sessionId in
            self?.interruptedSessions[sessionId] != nil
        }
        conversations[conversationId] = new
        return new
    }

    func ensureRunning(_ output: ConversationOutput) {
        if output.phase == .idle {
            output.phase = .running
        }
    }
}
