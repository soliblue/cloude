import Foundation
import CloudeShared

enum ConnectionEvent {
    case disconnect(conversationId: UUID, output: ConversationOutput)
    case transcription(String)
    case skills([Skill])
    case historySync(sessionId: String, messages: [HistoryMessage])
    case historySyncError(sessionId: String, error: String)

    case reconnectRunning(conversationId: UUID)
    case turnCompleted(conversationId: UUID)
    case liveSnapshot(conversationId: UUID)
    case resumeBegin(conversationId: UUID, messageId: UUID)

    case defaultWorkingDirectory(path: String, environmentId: UUID)
    case authenticated(environmentId: UUID)
    case renameConversation(conversationId: UUID, name: String)
    case setConversationSymbol(conversationId: UUID, symbol: String?)
    case sessionIdReceived(conversationId: UUID, sessionId: String)
    case lastAssistantMessageCostUpdate(conversationId: UUID, costUsd: Double)
    case deleteConversation(conversationId: UUID)
    case switchConversation(conversationId: UUID)
    case notify(title: String?, body: String)
    case openURL(String)
    case haptic(String)
}
