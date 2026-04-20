import Foundation
import CloudeShared

extension EnvironmentConversationRuntime {
    func resumeInterruptedSessions() {
        for (sessionId, target) in interruptedSessions {
            conversation(for: target.conversationId).resume(sessionId: sessionId, lastSeq: conversation(for: target.conversationId).output.lastSeenSeq)
        }
    }
}
