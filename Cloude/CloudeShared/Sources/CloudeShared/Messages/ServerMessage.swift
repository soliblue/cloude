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
    case fileContent(path: String, data: String, mimeType: String, size: Int64)
    case sessionId(id: String, conversationId: String?)
    case missedResponse(sessionId: String, text: String, completedAt: Date)
    case noMissedResponse(sessionId: String)
    case toolCall(name: String, input: String?, toolId: String, parentToolId: String?, conversationId: String?, textPosition: Int?)
    case runStats(durationMs: Int, costUsd: Double, conversationId: String?)
    case gitStatusResult(status: GitStatusInfo)
    case gitDiffResult(path: String, diff: String)
    case gitCommitResult(success: Bool, message: String?)
    case transcription(text: String)
    case whisperReady(ready: Bool)
    case heartbeatConfig(intervalMinutes: Int?, unreadCount: Int, sessionId: String?)
    case heartbeatOutput(text: String)
    case heartbeatComplete(message: String)
    case memories(sections: [MemorySection])

    enum CodingKeys: String, CodingKey {
        case type, text, path, diff, content, base64, state, success, message, entries, data, mimeType, size, id, sessionId, completedAt, name, input, status, branch, ahead, behind, files, durationMs, costUsd, toolId, parentToolId, ready, conversationId, intervalMinutes, unreadCount, sections, textPosition
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
            self = .fileContent(path: path, data: data, mimeType: mimeType, size: size)
        case "session_id":
            let id = try container.decode(String.self, forKey: .id)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            self = .sessionId(id: id, conversationId: conversationId)
        case "missed_response":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            let text = try container.decode(String.self, forKey: .text)
            let completedAt = try container.decode(Date.self, forKey: .completedAt)
            self = .missedResponse(sessionId: sessionId, text: text, completedAt: completedAt)
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
            let sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
            self = .heartbeatConfig(intervalMinutes: intervalMinutes, unreadCount: unreadCount, sessionId: sessionId)
        case "heartbeat_output":
            let text = try container.decode(String.self, forKey: .text)
            self = .heartbeatOutput(text: text)
        case "heartbeat_complete":
            let message = try container.decode(String.self, forKey: .message)
            self = .heartbeatComplete(message: message)
        case "memories":
            let sections = try container.decode([MemorySection].self, forKey: .sections)
            self = .memories(sections: sections)
        default:
            throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.type], debugDescription: "Unknown type: \(type)"))
        }
    }
}
