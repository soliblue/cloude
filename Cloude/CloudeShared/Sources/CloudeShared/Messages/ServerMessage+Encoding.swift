import Foundation

extension ServerMessage {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .output(let text, let conversationId, let seq):
            try container.encode("output", forKey: .type)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
            try container.encodeIfPresent(seq, forKey: .seq)
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
        case .toolCall(let name, let input, let toolId, let parentToolId, let conversationId, let textPosition, let editInfo, let seq):
            try container.encode("tool_call", forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(input, forKey: .input)
            try container.encode(toolId, forKey: .toolId)
            try container.encodeIfPresent(parentToolId, forKey: .parentToolId)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
            try container.encodeIfPresent(textPosition, forKey: .textPosition)
            try container.encodeIfPresent(editInfo, forKey: .editInfo)
            try container.encodeIfPresent(seq, forKey: .seq)
        case .toolResult(let toolId, let summary, let output, let conversationId, let seq):
            try container.encode("tool_result", forKey: .type)
            try container.encode(toolId, forKey: .toolId)
            try container.encodeIfPresent(summary, forKey: .summary)
            try container.encodeIfPresent(output, forKey: .output)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
            try container.encodeIfPresent(seq, forKey: .seq)
        case .runStats(let durationMs, let costUsd, let model, let conversationId, let seq):
            try container.encode("run_stats", forKey: .type)
            try container.encode(durationMs, forKey: .durationMs)
            try container.encode(costUsd, forKey: .costUsd)
            try container.encodeIfPresent(model, forKey: .model)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
            try container.encodeIfPresent(seq, forKey: .seq)
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
        case .gitLogResult(let path, let commits):
            try container.encode("git_log_result", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encode(commits, forKey: .commits)
        case .transcription(let text):
            try container.encode("transcription", forKey: .type)
            try container.encode(text, forKey: .text)
        case .whisperReady(let ready):
            try container.encode("whisper_ready", forKey: .type)
            try container.encode(ready, forKey: .ready)
        case .processList, .defaultWorkingDirectory, .skills, .historySync, .historySyncError,
             .fileChunk, .fileThumbnail, .fileSearchResults, .messageUUID,
             .nameSuggestion, .pong, .resumeFromResponse:
            try encodeExtendedCases(&container)
        }
    }
}
