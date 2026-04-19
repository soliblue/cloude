import Foundation

extension ServerMessage {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        if let decoded = try Self.decodeCoreTypes(type: type, container: container) {
            self = decoded
        } else if let decoded = try Self.decodeExtendedTypes(type: type, container: container) {
            self = decoded
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.type], debugDescription: "Unknown type: \(type)"))
        }
    }

    static func decodeCoreTypes(type: String, container: KeyedDecodingContainer<CodingKeys>) throws -> Self? {
        switch type {
        case "output":
            let text = try container.decode(String.self, forKey: .text)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            let seq = try container.decodeIfPresent(Int.self, forKey: .seq)
            return .output(text: text, conversationId: conversationId, seq: seq)
        case "status":
            let state = try container.decode(AgentState.self, forKey: .state)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            return .status(state: state, conversationId: conversationId)
        case "auth_required":
            return .authRequired
        case "auth_result":
            let success = try container.decode(Bool.self, forKey: .success)
            let message = try container.decodeIfPresent(String.self, forKey: .message)
            return .authResult(success: success, message: message)
        case "error":
            let message = try container.decode(String.self, forKey: .message)
            return .error(message: message)
        case "directory_listing":
            let path = try container.decode(String.self, forKey: .path)
            let entries = try container.decode([FileEntry].self, forKey: .entries)
            return .directoryListing(path: path, entries: entries)
        case "file_content":
            let path = try container.decode(String.self, forKey: .path)
            let data = try container.decode(String.self, forKey: .data)
            let mimeType = try container.decode(String.self, forKey: .mimeType)
            let size = try container.decode(Int64.self, forKey: .size)
            let truncated = try container.decodeIfPresent(Bool.self, forKey: .truncated) ?? false
            return .fileContent(path: path, data: data, mimeType: mimeType, size: size, truncated: truncated)
        case "session_id":
            let id = try container.decode(String.self, forKey: .id)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            return .sessionId(id: id, conversationId: conversationId)
        case "tool_call":
            let name = try container.decode(String.self, forKey: .name)
            let input = try container.decodeIfPresent(String.self, forKey: .input)
            let toolId = try container.decode(String.self, forKey: .toolId)
            let parentToolId = try container.decodeIfPresent(String.self, forKey: .parentToolId)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            let textPosition = try container.decodeIfPresent(Int.self, forKey: .textPosition)
            let editInfo = try container.decodeIfPresent(EditInfo.self, forKey: .editInfo)
            let seq = try container.decodeIfPresent(Int.self, forKey: .seq)
            return .toolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId, conversationId: conversationId, textPosition: textPosition, editInfo: editInfo, seq: seq)
        case "tool_result":
            let toolId = try container.decode(String.self, forKey: .toolId)
            let summary = try container.decodeIfPresent(String.self, forKey: .summary)
            let output = try container.decodeIfPresent(String.self, forKey: .output)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            let seq = try container.decodeIfPresent(Int.self, forKey: .seq)
            return .toolResult(toolId: toolId, summary: summary, output: output, conversationId: conversationId, seq: seq)
        case "run_stats":
            let durationMs = try container.decode(Int.self, forKey: .durationMs)
            let costUsd = try container.decode(Double.self, forKey: .costUsd)
            let model = try container.decodeIfPresent(String.self, forKey: .model)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            let seq = try container.decodeIfPresent(Int.self, forKey: .seq)
            return .runStats(durationMs: durationMs, costUsd: costUsd, model: model, conversationId: conversationId, seq: seq)
        case "git_status_result":
            let status = try container.decode(GitStatusInfo.self, forKey: .status)
            return .gitStatusResult(status: status)
        case "git_diff_result":
            let path = try container.decode(String.self, forKey: .path)
            let diff = try container.decode(String.self, forKey: .diff)
            return .gitDiffResult(path: path, diff: diff)
        case "git_commit_result":
            let success = try container.decode(Bool.self, forKey: .success)
            let message = try container.decodeIfPresent(String.self, forKey: .message)
            return .gitCommitResult(success: success, message: message)
        case "git_log_result":
            let path = try container.decode(String.self, forKey: .path)
            let commits = try container.decode([GitCommit].self, forKey: .commits)
            return .gitLogResult(path: path, commits: commits)
        case "transcription":
            let text = try container.decode(String.self, forKey: .text)
            return .transcription(text: text)
        case "whisper_ready":
            let ready = try container.decode(Bool.self, forKey: .ready)
            return .whisperReady(ready: ready)
        case "pong":
            let sentAt = try container.decode(Double.self, forKey: .sentAt)
            let serverAt = try container.decode(Double.self, forKey: .serverAt)
            return .pong(sentAt: sentAt, serverAt: serverAt)
        default:
            return nil
        }
    }
}
