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
        case .fileContent(let path, let data, let mimeType, let size):
            try container.encode("file_content", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encode(data, forKey: .data)
            try container.encode(mimeType, forKey: .mimeType)
            try container.encode(size, forKey: .size)
        case .sessionId(let id, let conversationId):
            try container.encode("session_id", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
        case .missedResponse(let sessionId, let text, let completedAt):
            try container.encode("missed_response", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)
            try container.encode(text, forKey: .text)
            try container.encode(completedAt, forKey: .completedAt)
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
        case .heartbeatConfig(let intervalMinutes, let unreadCount, let sessionId):
            try container.encode("heartbeat_config", forKey: .type)
            try container.encodeIfPresent(intervalMinutes, forKey: .intervalMinutes)
            try container.encode(unreadCount, forKey: .unreadCount)
            try container.encodeIfPresent(sessionId, forKey: .sessionId)
        case .heartbeatOutput(let text):
            try container.encode("heartbeat_output", forKey: .type)
            try container.encode(text, forKey: .text)
        case .heartbeatComplete(let message):
            try container.encode("heartbeat_complete", forKey: .type)
            try container.encode(message, forKey: .message)
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
        }
    }
}
