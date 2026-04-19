import Foundation

public enum ReplayedEvent: Codable {
    case output(text: String, conversationId: String?, seq: Int)
    case toolCall(name: String, input: String?, toolId: String, parentToolId: String?, conversationId: String?, textPosition: Int?, editInfo: EditInfo?, seq: Int)
    case toolResult(toolId: String, summary: String?, output: String?, conversationId: String?, seq: Int)
    case runStats(durationMs: Int, costUsd: Double, model: String?, conversationId: String?, seq: Int)

    enum CodingKeys: String, CodingKey {
        case kind, text, conversationId, name, input, toolId, parentToolId, textPosition, editInfo, summary, output, durationMs, costUsd, model, seq
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .output(let text, let conversationId, let seq):
            try container.encode("output", forKey: .kind)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
            try container.encode(seq, forKey: .seq)
        case .toolCall(let name, let input, let toolId, let parentToolId, let conversationId, let textPosition, let editInfo, let seq):
            try container.encode("tool_call", forKey: .kind)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(input, forKey: .input)
            try container.encode(toolId, forKey: .toolId)
            try container.encodeIfPresent(parentToolId, forKey: .parentToolId)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
            try container.encodeIfPresent(textPosition, forKey: .textPosition)
            try container.encodeIfPresent(editInfo, forKey: .editInfo)
            try container.encode(seq, forKey: .seq)
        case .toolResult(let toolId, let summary, let output, let conversationId, let seq):
            try container.encode("tool_result", forKey: .kind)
            try container.encode(toolId, forKey: .toolId)
            try container.encodeIfPresent(summary, forKey: .summary)
            try container.encodeIfPresent(output, forKey: .output)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
            try container.encode(seq, forKey: .seq)
        case .runStats(let durationMs, let costUsd, let model, let conversationId, let seq):
            try container.encode("run_stats", forKey: .kind)
            try container.encode(durationMs, forKey: .durationMs)
            try container.encode(costUsd, forKey: .costUsd)
            try container.encodeIfPresent(model, forKey: .model)
            try container.encodeIfPresent(conversationId, forKey: .conversationId)
            try container.encode(seq, forKey: .seq)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        let seq = try container.decode(Int.self, forKey: .seq)
        switch kind {
        case "output":
            let text = try container.decode(String.self, forKey: .text)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            self = .output(text: text, conversationId: conversationId, seq: seq)
        case "tool_call":
            let name = try container.decode(String.self, forKey: .name)
            let input = try container.decodeIfPresent(String.self, forKey: .input)
            let toolId = try container.decode(String.self, forKey: .toolId)
            let parentToolId = try container.decodeIfPresent(String.self, forKey: .parentToolId)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            let textPosition = try container.decodeIfPresent(Int.self, forKey: .textPosition)
            let editInfo = try container.decodeIfPresent(EditInfo.self, forKey: .editInfo)
            self = .toolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId, conversationId: conversationId, textPosition: textPosition, editInfo: editInfo, seq: seq)
        case "tool_result":
            let toolId = try container.decode(String.self, forKey: .toolId)
            let summary = try container.decodeIfPresent(String.self, forKey: .summary)
            let output = try container.decodeIfPresent(String.self, forKey: .output)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            self = .toolResult(toolId: toolId, summary: summary, output: output, conversationId: conversationId, seq: seq)
        case "run_stats":
            let durationMs = try container.decode(Int.self, forKey: .durationMs)
            let costUsd = try container.decode(Double.self, forKey: .costUsd)
            let model = try container.decodeIfPresent(String.self, forKey: .model)
            let conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
            self = .runStats(durationMs: durationMs, costUsd: costUsd, model: model, conversationId: conversationId, seq: seq)
        default:
            throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.kind], debugDescription: "Unknown replayed event kind: \(kind)"))
        }
    }
}

public enum ServerMessage: Codable {
    case output(text: String, conversationId: String?, seq: Int? = nil)
    case status(state: AgentState, conversationId: String?)
    case authRequired
    case authResult(success: Bool, message: String?)
    case error(message: String)
    case directoryListing(path: String, entries: [FileEntry])
    case fileContent(path: String, data: String, mimeType: String, size: Int64, truncated: Bool)
    case sessionId(id: String, conversationId: String?)
    case toolCall(name: String, input: String?, toolId: String, parentToolId: String?, conversationId: String?, textPosition: Int?, editInfo: EditInfo? = nil, seq: Int? = nil)
    case toolResult(toolId: String, summary: String?, output: String?, conversationId: String?, seq: Int? = nil)
    case runStats(durationMs: Int, costUsd: Double, model: String?, conversationId: String?, seq: Int? = nil)
    case resumeFromResponse(sessionId: String, events: [ReplayedEvent], historyOnly: Bool)
    case gitStatusResult(status: GitStatusInfo)
    case gitDiffResult(path: String, diff: String)
    case gitCommitResult(success: Bool, message: String?)
    case gitLogResult(path: String, commits: [GitCommit])
    case transcription(text: String)
    case whisperReady(ready: Bool)
    case defaultWorkingDirectory(path: String)
    case skills([Skill])
    case historySync(sessionId: String, messages: [HistoryMessage])
    case historySyncError(sessionId: String, error: String)
    case fileChunk(path: String, chunkIndex: Int, totalChunks: Int, data: String, mimeType: String, size: Int64)
    case fileThumbnail(path: String, data: String, fullSize: Int64)
    case fileSearchResults(files: [String])
    case messageUUID(uuid: String, conversationId: String?)
    case nameSuggestion(name: String, symbol: String?, conversationId: String)
    case pong(sentAt: Double, serverAt: Double)

    enum CodingKeys: String, CodingKey {
        case type, text, path, diff, state, success, message, entries, data, mimeType, size, truncated, id, sessionId, name, input, status, files, durationMs, costUsd, model, toolId, parentToolId, ready, conversationId, textPosition, symbol, skills, messages, error, chunkIndex, totalChunks, fullSize, uuid, summary, output, filename, editInfo, sentAt, serverAt, commits, seq, events, historyOnly
    }
}
