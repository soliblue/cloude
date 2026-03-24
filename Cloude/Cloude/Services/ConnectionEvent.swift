import Foundation
import CloudeShared

enum ConnectionEvent {
    // Files
    case directoryListing(path: String, entries: [FileEntry], environmentId: UUID?)
    case fileContent(path: String, data: String, mimeType: String, size: Int64, truncated: Bool)
    case fileChunk(path: String, chunkIndex: Int, totalChunks: Int, data: String, mimeType: String, size: Int64)
    case fileThumbnail(path: String, data: String, fullSize: Int64)
    case fileSearchResults(files: [String], query: String)
    case fileError(String)

    // Chat/session
    case missedResponse(sessionId: String, text: String, completedAt: Date, toolCalls: [StoredToolCall], interruptedConversationId: UUID?, interruptedMessageId: UUID?)
    case gitStatus(path: String, status: GitStatusInfo, environmentId: UUID?)
    case gitDiff(path: String, diff: String)
    case disconnect(conversationId: UUID, output: ConversationOutput)
    case transcription(String)
    case memories([MemorySection])
    case skills([Skill])
    case historySync(sessionId: String, messages: [HistoryMessage])
    case historySyncError(sessionId: String, error: String)

    // Plans
    case plans([String: [PlanItem]])
    case planDeleted(stage: String, filename: String)

    // Streaming lifecycle
    case streamingStarted(conversationId: UUID)

    // UI / orchestration
    case authenticated
    case usageStats(UsageStats)
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
    case question(questions: [Question], conversationId: UUID?)
    case screenshot(conversationId: UUID?)
    case terminalOutput(output: String, exitCode: Int?, isError: Bool, terminalId: String?)
    case whiteboard(action: String, json: [String: Any], conversationId: UUID?)

    // Git branches
    case branchAttached(branch: String, worktreePath: String, conversationId: UUID?)
    case branchList(branches: [String], current: String)
}
