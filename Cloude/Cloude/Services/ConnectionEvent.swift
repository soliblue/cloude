import Foundation
import CloudeShared

enum ConnectionEvent {
    // Files
    case directoryListing(path: String, entries: [FileEntry])
    case fileContent(path: String, data: String, mimeType: String, size: Int64, truncated: Bool)
    case fileChunk(path: String, chunkIndex: Int, totalChunks: Int, data: String, mimeType: String, size: Int64)
    case fileThumbnail(path: String, data: String, fullSize: Int64)
    case fileSearchResults(files: [String], query: String)
    case fileError(String)

    // Chat/session
    case missedResponse(sessionId: String, text: String, completedAt: Date, toolCalls: [StoredToolCall], interruptedConversationId: UUID?, interruptedMessageId: UUID?)
    case gitStatus(path: String, status: GitStatusInfo)
    case gitDiff(path: String, diff: String)
    case disconnect(conversationId: UUID, output: ConversationOutput)
    case transcription(String)
    case ttsAudio(data: Data, messageId: String)
    case heartbeatConfig(intervalMinutes: Int?, unreadCount: Int)
    case heartbeatSkipped(conversationId: UUID?)
    case memories([MemorySection])
    case skills([Skill])
    case historySync(sessionId: String, messages: [HistoryMessage])
    case historySyncError(sessionId: String, error: String)

    // Plans
    case plans([String: [PlanItem]])
    case planDeleted(stage: String, filename: String)

    // Scheduled Tasks
    case scheduledTasks([ScheduledTask])
    case scheduledTaskUpdated(ScheduledTask)
    case scheduledTaskDeleted(taskId: String)

    // UI / orchestration
    case authenticated
    case usageStats(UsageStats)
    case suggestionsResult(suggestions: [String], conversationId: UUID?)
    case renameConversation(conversationId: UUID, name: String)
    case setConversationSymbol(conversationId: UUID, symbol: String?)
    case sessionIdReceived(conversationId: UUID, sessionId: String)
    case conversationOutputStarted(conversationId: UUID)
    case lastAssistantMessageCostUpdate(conversationId: UUID, costUsd: Double)
    case deleteConversation(conversationId: UUID)
    case switchConversation(conversationId: UUID)
    case notify(title: String?, body: String)
    case clipboard(String)
    case openURL(String)
    case haptic(String)
    case speak(String)
    case question(questions: [Question], conversationId: UUID?)
    case screenshot(conversationId: UUID?)
}
