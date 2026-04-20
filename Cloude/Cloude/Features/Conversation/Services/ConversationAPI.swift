import Combine
import Foundation
import CloudeShared

@MainActor
final class ConversationAPI: ObservableObject {
    let environmentId: UUID
    let conversationId: UUID
    let output = ConversationOutput()

    var send: ((ClientMessage) -> Void)?
    var resolveDefaultWorkingDirectory: () -> String? = { nil }
    var trackInterruptedSession: ((String, UUID?) -> Void)?
    var hasInterruptedSession: ((String) -> Bool)?

    init(environmentId: UUID, conversationId: UUID) {
        self.environmentId = environmentId
        self.conversationId = conversationId
    }

    func resume(sessionId: String, lastSeq: Int) {
        AppLogger.connectionInfo("heuristic_counter=resumeFrom_send sessionId=\(sessionId) lastSeq=\(lastSeq)")
        send?(.resumeFrom(sessionId: sessionId, lastSeq: lastSeq))
    }

    func rememberInterruptedSession(sessionId: String, messageId: UUID?) {
        trackInterruptedSession?(sessionId, messageId)
    }

    func isTrackingInterruptedSession(_ sessionId: String) -> Bool {
        hasInterruptedSession?(sessionId) ?? false
    }

    func sendChat(_ message: String, workingDirectory: String? = nil, sessionId: String? = nil, isNewSession: Bool = true, imagesBase64: [String]? = nil, filesBase64: [AttachedFilePayload]? = nil, conversationName: String? = nil, forkSession: Bool = false, effort: String? = nil, model: String? = nil) {
        AppLogger.beginInterval("chat.firstToken", key: conversationId.uuidString, details: "chars=\(message.count)")
        AppLogger.beginInterval("chat.complete", key: conversationId.uuidString, details: "chars=\(message.count)")
        output.reset()
        output.phase = .running
        send?(.chat(message: message, workingDirectory: workingDirectory ?? resolveDefaultWorkingDirectory(), sessionId: sessionId, isNewSession: isNewSession, imagesBase64: imagesBase64, filesBase64: filesBase64, conversationId: conversationId.uuidString, conversationName: conversationName, forkSession: forkSession, effort: effort, model: model))
    }

    func abort() {
        send?(.abort(conversationId: conversationId.uuidString))
    }

    func syncHistory(sessionId: String, workingDirectory: String) {
        send?(.syncHistory(sessionId: sessionId, workingDirectory: workingDirectory))
    }

    func requestNameSuggestion(text: String, context: [String]) {
        send?(.suggestName(text: text, context: context, conversationId: conversationId.uuidString))
    }
}
