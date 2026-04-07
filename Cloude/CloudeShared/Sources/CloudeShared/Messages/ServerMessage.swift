import Foundation

public enum ServerMessage: Codable {
    case output(text: String, conversationId: String?)
    case fileChange(path: String, diff: String?, content: String?)
    case image(path: String, base64: String)
    case status(state: AgentState, conversationId: String?)
    case authRequired
    case authResult(success: Bool, message: String?)
    case error(message: String)
    case directoryListing(path: String, entries: [FileEntry])
    case fileContent(path: String, data: String, mimeType: String, size: Int64, truncated: Bool)
    case sessionId(id: String, conversationId: String?)
    case missedResponse(sessionId: String, text: String, completedAt: Date, toolCalls: [StoredToolCall], durationMs: Int?, costUsd: Double?, model: String?)
    case noMissedResponse(sessionId: String)
    case toolCall(name: String, input: String?, toolId: String, parentToolId: String?, conversationId: String?, textPosition: Int?, editInfo: EditInfo? = nil)
    case toolResult(toolId: String, summary: String?, output: String?, conversationId: String?)
    case runStats(durationMs: Int, costUsd: Double, model: String?, conversationId: String?)
    case gitStatusResult(status: GitStatusInfo)
    case gitDiffResult(path: String, diff: String)
    case gitCommitResult(success: Bool, message: String?)
    case gitLogResult(path: String, commits: [GitCommit])
    case transcription(text: String)
    case whisperReady(ready: Bool)
    case memories(sections: [MemorySection])
    case processList(processes: [AgentProcessInfo])
    case defaultWorkingDirectory(path: String)
    case skills([Skill])
    case historySync(sessionId: String, messages: [HistoryMessage])
    case historySyncError(sessionId: String, error: String)
    case fileChunk(path: String, chunkIndex: Int, totalChunks: Int, data: String, mimeType: String, size: Int64)
    case fileThumbnail(path: String, data: String, fullSize: Int64)
    case fileSearchResults(files: [String], query: String)
    case remoteSessionList(sessions: [RemoteSession])
    case messageUUID(uuid: String, conversationId: String?)
    case nameSuggestion(name: String, symbol: String?, conversationId: String)
    case plans(stages: [String: [PlanItem]])
    case planDeleted(stage: String, filename: String)
    case usageStats(stats: UsageStats)
    case terminalOutput(output: String, exitCode: Int?, isError: Bool, terminalId: String?)
    case pong(sentAt: Double, serverAt: Double)

    enum CodingKeys: String, CodingKey {
        case type, text, path, diff, content, base64, state, success, message, entries, data, mimeType, size, truncated, id, sessionId, completedAt, name, input, status, files, durationMs, costUsd, model, toolId, parentToolId, ready, conversationId, sections, textPosition, symbol, processes, skills, messages, error, toolCalls, chunkIndex, totalChunks, fullSize, query, sessions, uuid, summary, output, stages, stage, filename, stats, exitCode, isError, terminalId, editInfo, sentAt, serverAt, commits
    }
}
