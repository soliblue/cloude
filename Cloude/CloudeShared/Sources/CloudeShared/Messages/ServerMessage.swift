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
    case missedResponse(sessionId: String, text: String, completedAt: Date, toolCalls: [StoredToolCall])
    case noMissedResponse(sessionId: String)
    case toolCall(name: String, input: String?, toolId: String, parentToolId: String?, conversationId: String?, textPosition: Int?)
    case toolResult(toolId: String, summary: String?, conversationId: String?)
    case runStats(durationMs: Int, costUsd: Double, conversationId: String?)
    case gitStatusResult(status: GitStatusInfo)
    case gitDiffResult(path: String, diff: String)
    case gitCommitResult(success: Bool, message: String?)
    case transcription(text: String)
    case whisperReady(ready: Bool)
    case heartbeatConfig(intervalMinutes: Int?, unreadCount: Int)
    case memories(sections: [MemorySection])
    case renameConversation(conversationId: String, name: String)
    case setConversationSymbol(conversationId: String, symbol: String?)
    case processList(processes: [AgentProcessInfo])
    case memoryAdded(target: String, section: String, text: String, conversationId: String?)
    case defaultWorkingDirectory(path: String)
    case skills([Skill])
    case historySync(sessionId: String, messages: [HistoryMessage])
    case historySyncError(sessionId: String, error: String)
    case heartbeatSkipped(conversationId: String?)
    case fileChunk(path: String, chunkIndex: Int, totalChunks: Int, data: String, mimeType: String, size: Int64)
    case fileThumbnail(path: String, data: String, fullSize: Int64)
    case deleteConversation(conversationId: String)
    case notify(title: String?, body: String, conversationId: String?)
    case clipboard(text: String)
    case openURL(url: String)
    case haptic(style: String)
    case speak(text: String)
    case switchConversation(conversationId: String)
    case question(questions: [Question], conversationId: String?)
    case fileSearchResults(files: [String], query: String)
    case remoteSessionList(sessions: [RemoteSession])
    case messageUUID(uuid: String, conversationId: String?)
    case screenshot(conversationId: String?)

    enum CodingKeys: String, CodingKey {
        case type, text, path, diff, content, base64, state, success, message, entries, data, mimeType, size, truncated, id, sessionId, completedAt, name, input, status, branch, ahead, behind, files, durationMs, costUsd, toolId, parentToolId, ready, conversationId, intervalMinutes, unreadCount, sections, textPosition, symbol, processes, target, section, skills, messages, error, toolCalls, chunkIndex, totalChunks, fullSize, title, body, url, style, questions, query, sessions, uuid, summary
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "output":
            let text = try container.decode(String.self, forKey: .text)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            self = .output(text: text, conversationId: conversationId)
        case "file_change":
            let path = try container.decode(String.self, forKey: .path)
            let diff = try container.decodeIfPresent(String.self, forKey: .diff)
            let content = try container.decodeIfPresent(String.self, forKey: .content)
            self = .fileChange(path: path, diff: diff, content: content)
        case "image":
            let path = try container.decode(String.self, forKey: .path)
            let base64 = try container.decode(String.self, forKey: .base64)
            self = .image(path: path, base64: base64)
        case "status":
            let state = try container.decode(AgentState.self, forKey: .state)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            self = .status(state: state, conversationId: conversationId)
        case "auth_required":
            self = .authRequired
        case "auth_result":
            let success = try container.decode(Bool.self, forKey: .success)
            let message = try container.decodeIfPresent(String.self, forKey: .message)
            self = .authResult(success: success, message: message)
        case "error":
            let message = try container.decode(String.self, forKey: .message)
            self = .error(message: message)
        case "directory_listing":
            let path = try container.decode(String.self, forKey: .path)
            let entries = try container.decode([FileEntry].self, forKey: .entries)
            self = .directoryListing(path: path, entries: entries)
        case "file_content":
            let path = try container.decode(String.self, forKey: .path)
            let data = try container.decode(String.self, forKey: .data)
            let mimeType = try container.decode(String.self, forKey: .mimeType)
            let size = try container.decode(Int64.self, forKey: .size)
            let truncated = try container.decodeIfPresent(Bool.self, forKey: .truncated) ?? false
            self = .fileContent(path: path, data: data, mimeType: mimeType, size: size, truncated: truncated)
        case "session_id":
            let id = try container.decode(String.self, forKey: .id)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            self = .sessionId(id: id, conversationId: conversationId)
        case "missed_response":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            let text = try container.decode(String.self, forKey: .text)
            let completedAt = try container.decode(Date.self, forKey: .completedAt)
            let toolCalls = try container.decodeIfPresent([StoredToolCall].self, forKey: .toolCalls) ?? []
            self = .missedResponse(sessionId: sessionId, text: text, completedAt: completedAt, toolCalls: toolCalls)
        case "no_missed_response":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            self = .noMissedResponse(sessionId: sessionId)
        case "tool_call":
            let name = try container.decode(String.self, forKey: .name)
            let input = try container.decodeIfPresent(String.self, forKey: .input)
            let toolId = try container.decode(String.self, forKey: .toolId)
            let parentToolId = try container.decodeIfPresent(String.self, forKey: .parentToolId)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            let textPosition = try container.decodeIfPresent(Int.self, forKey: .textPosition)
            self = .toolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId, conversationId: conversationId, textPosition: textPosition)
        case "tool_result":
            let toolId = try container.decode(String.self, forKey: .toolId)
            let summary = try container.decodeIfPresent(String.self, forKey: .summary)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            self = .toolResult(toolId: toolId, summary: summary, conversationId: conversationId)
        case "run_stats":
            let durationMs = try container.decode(Int.self, forKey: .durationMs)
            let costUsd = try container.decode(Double.self, forKey: .costUsd)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            self = .runStats(durationMs: durationMs, costUsd: costUsd, conversationId: conversationId)
        case "git_status_result":
            let status = try container.decode(GitStatusInfo.self, forKey: .status)
            self = .gitStatusResult(status: status)
        case "git_diff_result":
            let path = try container.decode(String.self, forKey: .path)
            let diff = try container.decode(String.self, forKey: .diff)
            self = .gitDiffResult(path: path, diff: diff)
        case "git_commit_result":
            let success = try container.decode(Bool.self, forKey: .success)
            let message = try container.decodeIfPresent(String.self, forKey: .message)
            self = .gitCommitResult(success: success, message: message)
        case "transcription":
            let text = try container.decode(String.self, forKey: .text)
            self = .transcription(text: text)
        case "whisper_ready":
            let ready = try container.decode(Bool.self, forKey: .ready)
            self = .whisperReady(ready: ready)
        case "heartbeat_config":
            let intervalMinutes = try container.decodeIfPresent(Int.self, forKey: .intervalMinutes)
            let unreadCount = try container.decode(Int.self, forKey: .unreadCount)
            self = .heartbeatConfig(intervalMinutes: intervalMinutes, unreadCount: unreadCount)
        case "memories":
            let sections = try container.decode([MemorySection].self, forKey: .sections)
            self = .memories(sections: sections)
        case "rename_conversation":
            let conversationId = try container.decode(String.self, forKey: .conversationId)
            let name = try container.decode(String.self, forKey: .name)
            self = .renameConversation(conversationId: conversationId, name: name)
        case "set_conversation_symbol":
            let conversationId = try container.decode(String.self, forKey: .conversationId)
            let symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
            self = .setConversationSymbol(conversationId: conversationId, symbol: symbol)
        case "process_list":
            let processes = try container.decode([AgentProcessInfo].self, forKey: .processes)
            self = .processList(processes: processes)
        case "memory_added":
            let target = try container.decode(String.self, forKey: .target)
            let section = try container.decode(String.self, forKey: .section)
            let text = try container.decode(String.self, forKey: .text)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            self = .memoryAdded(target: target, section: section, text: text, conversationId: conversationId)
        case "default_working_directory":
            let path = try container.decode(String.self, forKey: .path)
            self = .defaultWorkingDirectory(path: path)
        case "skills":
            let skills = try container.decode([Skill].self, forKey: .skills)
            self = .skills(skills)
        case "history_sync":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            let messages = try container.decode([HistoryMessage].self, forKey: .messages)
            self = .historySync(sessionId: sessionId, messages: messages)
        case "history_sync_error":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            let error = try container.decode(String.self, forKey: .error)
            self = .historySyncError(sessionId: sessionId, error: error)
        case "heartbeat_skipped":
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            self = .heartbeatSkipped(conversationId: conversationId)
        case "file_chunk":
            let path = try container.decode(String.self, forKey: .path)
            let chunkIndex = try container.decode(Int.self, forKey: .chunkIndex)
            let totalChunks = try container.decode(Int.self, forKey: .totalChunks)
            let data = try container.decode(String.self, forKey: .data)
            let mimeType = try container.decode(String.self, forKey: .mimeType)
            let size = try container.decode(Int64.self, forKey: .size)
            self = .fileChunk(path: path, chunkIndex: chunkIndex, totalChunks: totalChunks, data: data, mimeType: mimeType, size: size)
        case "file_thumbnail":
            let path = try container.decode(String.self, forKey: .path)
            let data = try container.decode(String.self, forKey: .data)
            let fullSize = try container.decode(Int64.self, forKey: .fullSize)
            self = .fileThumbnail(path: path, data: data, fullSize: fullSize)
        case "delete_conversation":
            let conversationId = try container.decode(String.self, forKey: .conversationId)
            self = .deleteConversation(conversationId: conversationId)
        case "notify":
            let title = try container.decodeIfPresent(String.self, forKey: .title)
            let body = try container.decode(String.self, forKey: .body)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            self = .notify(title: title, body: body, conversationId: conversationId)
        case "clipboard":
            let text = try container.decode(String.self, forKey: .text)
            self = .clipboard(text: text)
        case "open_url":
            let url = try container.decode(String.self, forKey: .url)
            self = .openURL(url: url)
        case "haptic":
            let style = try container.decode(String.self, forKey: .style)
            self = .haptic(style: style)
        case "speak":
            let text = try container.decode(String.self, forKey: .text)
            self = .speak(text: text)
        case "switch_conversation":
            let conversationId = try container.decode(String.self, forKey: .conversationId)
            self = .switchConversation(conversationId: conversationId)
        case "question":
            let questions = try container.decode([Question].self, forKey: .questions)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            self = .question(questions: questions, conversationId: conversationId)
        case "file_search_results":
            let files = try container.decode([String].self, forKey: .files)
            let query = try container.decode(String.self, forKey: .query)
            self = .fileSearchResults(files: files, query: query)
        case "remote_session_list":
            let sessions = try container.decode([RemoteSession].self, forKey: .sessions)
            self = .remoteSessionList(sessions: sessions)
        case "message_uuid":
            let uuid = try container.decode(String.self, forKey: .uuid)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            self = .messageUUID(uuid: uuid, conversationId: conversationId)
        case "screenshot":
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            self = .screenshot(conversationId: conversationId)
        default:
            throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.type], debugDescription: "Unknown type: \(type)"))
        }
    }
}
