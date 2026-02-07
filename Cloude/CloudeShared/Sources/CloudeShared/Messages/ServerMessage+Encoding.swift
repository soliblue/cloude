import Foundation

extension ServerMessage {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .output(let text, let conversationId):
            try container.encode("output", forKey: .type)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
        case .fileChange(let path, let diff, let content):
            try container.encode("file_change", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encodeIfPresent(diff, forKey: .diff)
            try container.encodeIfPresent(content, forKey: .content)
        case .image(let path, let base64):
            try container.encode("image", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encode(base64, forKey: .base64)
        case .status(let state, let conversationId):
            try container.encode("status", forKey: .type)
            try container.encode(state, forKey: .state)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
        case .authRequired:
            try container.encode("auth_required", forKey: .type)
        case .authResult(let success, let message):
            try container.encode("auth_result", forKey: .type)
            try container.encode(success, forKey: .success)
            try container.encodeIfPresent(message, forKey: .message)
        case .error(let message):
            try container.encode("error", forKey: .type)
            try container.encode(message, forKey: .message)
        case .directoryListing(let path, let entries):
            try container.encode("directory_listing", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encode(entries, forKey: .entries)
        case .fileContent(let path, let data, let mimeType, let size, let truncated):
            try container.encode("file_content", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encode(data, forKey: .data)
            try container.encode(mimeType, forKey: .mimeType)
            try container.encode(size, forKey: .size)
            try container.encode(truncated, forKey: .truncated)
        case .sessionId(let id, let conversationId):
            try container.encode("session_id", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
        case .missedResponse(let sessionId, let text, let completedAt, let toolCalls):
            try container.encode("missed_response", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)
            try container.encode(text, forKey: .text)
            try container.encode(completedAt, forKey: .completedAt)
            try container.encode(toolCalls, forKey: .toolCalls)
        case .noMissedResponse(let sessionId):
            try container.encode("no_missed_response", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)
        case .toolCall(let name, let input, let toolId, let parentToolId, let conversationId, let textPosition):
            try container.encode("tool_call", forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(input, forKey: .input)
            try container.encode(toolId, forKey: .toolId)
            try container.encodeIfPresent(parentToolId, forKey: .parentToolId)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
            try container.encodeIfPresent(textPosition, forKey: .textPosition)
        case .toolResult(let toolId, let summary, let conversationId):
            try container.encode("tool_result", forKey: .type)
            try container.encode(toolId, forKey: .toolId)
            try container.encodeIfPresent(summary, forKey: .summary)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
        case .runStats(let durationMs, let costUsd, let conversationId):
            try container.encode("run_stats", forKey: .type)
            try container.encode(durationMs, forKey: .durationMs)
            try container.encode(costUsd, forKey: .costUsd)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
        case .gitStatusResult(let status):
            try container.encode("git_status_result", forKey: .type)
            try container.encode(status, forKey: .status)
        case .gitDiffResult(let path, let diff):
            try container.encode("git_diff_result", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encode(diff, forKey: .diff)
        case .gitCommitResult(let success, let message):
            try container.encode("git_commit_result", forKey: .type)
            try container.encode(success, forKey: .success)
            try container.encodeIfPresent(message, forKey: .message)
        case .transcription(let text):
            try container.encode("transcription", forKey: .type)
            try container.encode(text, forKey: .text)
        case .whisperReady(let ready):
            try container.encode("whisper_ready", forKey: .type)
            try container.encode(ready, forKey: .ready)
        case .heartbeatConfig(let intervalMinutes, let unreadCount):
            try container.encode("heartbeat_config", forKey: .type)
            try container.encodeIfPresent(intervalMinutes, forKey: .intervalMinutes)
            try container.encode(unreadCount, forKey: .unreadCount)
        case .memories(let sections):
            try container.encode("memories", forKey: .type)
            try container.encode(sections, forKey: .sections)
        case .renameConversation(let conversationId, let name):
            try container.encode("rename_conversation", forKey: .type)
            try container.encode(conversationId, forKey: .conversationId)
            try container.encode(name, forKey: .name)
        case .setConversationSymbol(let conversationId, let symbol):
            try container.encode("set_conversation_symbol", forKey: .type)
            try container.encode(conversationId, forKey: .conversationId)
            try container.encodeIfPresent(symbol, forKey: .symbol)
        case .processList(let processes):
            try container.encode("process_list", forKey: .type)
            try container.encode(processes, forKey: .processes)
        case .memoryAdded(let target, let section, let text, let conversationId):
            try container.encode("memory_added", forKey: .type)
            try container.encode(target, forKey: .target)
            try container.encode(section, forKey: .section)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
        case .defaultWorkingDirectory(let path):
            try container.encode("default_working_directory", forKey: .type)
            try container.encode(path, forKey: .path)
        case .skills(let skills):
            try container.encode("skills", forKey: .type)
            try container.encode(skills, forKey: .skills)
        case .historySync(let sessionId, let messages):
            try container.encode("history_sync", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)
            try container.encode(messages, forKey: .messages)
        case .historySyncError(let sessionId, let error):
            try container.encode("history_sync_error", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)
            try container.encode(error, forKey: .error)
        case .heartbeatSkipped(let conversationId):
            try container.encode("heartbeat_skipped", forKey: .type)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
        case .fileChunk(let path, let chunkIndex, let totalChunks, let data, let mimeType, let size):
            try container.encode("file_chunk", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encode(chunkIndex, forKey: .chunkIndex)
            try container.encode(totalChunks, forKey: .totalChunks)
            try container.encode(data, forKey: .data)
            try container.encode(mimeType, forKey: .mimeType)
            try container.encode(size, forKey: .size)
        case .fileThumbnail(let path, let data, let fullSize):
            try container.encode("file_thumbnail", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encode(data, forKey: .data)
            try container.encode(fullSize, forKey: .fullSize)
        case .deleteConversation(let conversationId):
            try container.encode("delete_conversation", forKey: .type)
            try container.encode(conversationId, forKey: .conversationId)
        case .notify(let title, let body, let conversationId):
            try container.encode("notify", forKey: .type)
            try container.encodeIfPresent(title, forKey: .title)
            try container.encode(body, forKey: .body)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
        case .clipboard(let text):
            try container.encode("clipboard", forKey: .type)
            try container.encode(text, forKey: .text)
        case .openURL(let url):
            try container.encode("open_url", forKey: .type)
            try container.encode(url, forKey: .url)
        case .haptic(let style):
            try container.encode("haptic", forKey: .type)
            try container.encode(style, forKey: .style)
        case .speak(let text):
            try container.encode("speak", forKey: .type)
            try container.encode(text, forKey: .text)
        case .switchConversation(let conversationId):
            try container.encode("switch_conversation", forKey: .type)
            try container.encode(conversationId, forKey: .conversationId)
        case .question(let questions, let conversationId):
            try container.encode("question", forKey: .type)
            try container.encode(questions, forKey: .questions)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
        case .fileSearchResults(let files, let query):
            try container.encode("file_search_results", forKey: .type)
            try container.encode(files, forKey: .files)
            try container.encode(query, forKey: .query)
        case .remoteSessionList(let sessions):
            try container.encode("remote_session_list", forKey: .type)
            try container.encode(sessions, forKey: .sessions)
        case .messageUUID(let uuid, let conversationId):
            try container.encode("message_uuid", forKey: .type)
            try container.encode(uuid, forKey: .uuid)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
        case .screenshot(let conversationId):
            try container.encode("screenshot", forKey: .type)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
        case .teamCreated(let teamName, let leadAgentId, let conversationId):
            try container.encode("team_created", forKey: .type)
            try container.encode(teamName, forKey: .teamName)
            try container.encode(leadAgentId, forKey: .leadAgentId)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
        case .teammateSpawned(let teammate, let conversationId):
            try container.encode("teammate_spawned", forKey: .type)
            try container.encode(teammate, forKey: .teammate)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
        case .teammateUpdate(let teammateId, let status, let lastMessage, let lastMessageAt, let conversationId):
            try container.encode("teammate_update", forKey: .type)
            try container.encode(teammateId, forKey: .teammateId)
            try container.encodeIfPresent(status, forKey: .status)
            try container.encodeIfPresent(lastMessage, forKey: .lastMessage)
            try container.encodeIfPresent(lastMessageAt, forKey: .lastMessageAt)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
        case .teamDeleted(let conversationId):
            try container.encode("team_deleted", forKey: .type)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
        }
    }
}
