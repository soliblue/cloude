import Foundation
import CloudeShared

enum ConnectionEvent {
    case directoryListing(path: String, entries: [FileEntry], environmentId: UUID?)
    case fileContent(path: String, data: String, mimeType: String, size: Int64, truncated: Bool)
    case fileChunk(path: String, chunkIndex: Int, totalChunks: Int, data: String, mimeType: String, size: Int64)
    case fileThumbnail(path: String, data: String, fullSize: Int64)
    case fileSearchResults(files: [String])
    case fileError(String)

    case missedResponse(sessionId: String, text: String, completedAt: Date, toolCalls: [StoredToolCall], durationMs: Int?, costUsd: Double?, model: String?, interruptedConversationId: UUID?, interruptedMessageId: UUID?)
    case gitStatus(path: String, status: GitStatusInfo, environmentId: UUID?)
    case gitStatusError(path: String, message: String, environmentId: UUID?)
    case gitLog(path: String, commits: [GitCommit], environmentId: UUID?)
    case gitDiff(path: String, diff: String)
    case disconnect(conversationId: UUID, output: ConversationOutput)
    case transcription(String)
    case skills([Skill])
    case historySync(sessionId: String, messages: [HistoryMessage])
    case historySyncError(sessionId: String, error: String)

    case reconnectRunning(conversationId: UUID)
    case turnCompleted(conversationId: UUID)
    case liveSnapshot(conversationId: UUID)

    case defaultWorkingDirectory(path: String, environmentId: UUID)
    case authenticated
    case renameConversation(conversationId: UUID, name: String)
    case setConversationSymbol(conversationId: UUID, symbol: String?)
    case sessionIdReceived(conversationId: UUID, sessionId: String)
    case lastAssistantMessageCostUpdate(conversationId: UUID, costUsd: Double)
    case deleteConversation(conversationId: UUID)
    case switchConversation(conversationId: UUID)
    case notify(title: String?, body: String)
    case clipboard(String)
    case openURL(String)
    case haptic(String)
    case screenshot(conversationId: UUID?)
    case whiteboard(action: String, json: [String: Any], conversationId: UUID?)
}
