import Foundation

nonisolated struct DecodedToolUse: Equatable {
    let id: String
    let name: String
    let inputSummary: String
    let inputJSON: String
    let parentToolUseId: String?
}

nonisolated enum ChatStreamEvent {
    case usage(seq: Int, contextTokens: Int?, contextWindow: Int?)
    case sessionMetadata(seq: Int, threadId: String)
    case request(seq: Int, interaction: ChatInteraction)
    case requestResolved(seq: Int, requestId: String)
    case agentAttention(seq: Int, threadId: String, requestId: String, pending: Bool)
    case initialized(seq: Int, model: String?)
    case assistantTextDelta(seq: Int, text: String)
    case assistantThinkingDelta(seq: Int, text: String)
    case plan(seq: Int, itemId: String, text: String, delta: Bool, completed: Bool)
    case assistantFinal(
        seq: Int, text: String, thinking: String, thinkingRedacted: Bool,
        toolUses: [DecodedToolUse], model: String?, contextTokens: Int?)
    case toolOutputDelta(seq: Int, toolUseId: String, text: String)
    case toolResults(seq: Int, results: [ChatToolResult])
    case toolResult(seq: Int, toolUseId: String, text: String, isError: Bool)
    case result(seq: Int, costUsd: Double?, contextWindow: Int?)
    case aborted(seq: Int)
    case exited(seq: Int, code: Int)
    case error(seq: Int, message: String)
    case compacting(seq: Int)
    case replay(seq: Int)
    case unknown(seq: Int)

    var seq: Int {
        switch self {
        case .usage(let s, _, _), .sessionMetadata(let s, _), .request(let s, _), .requestResolved(let s, _),
            .agentAttention(let s, _, _, _), .initialized(let s, _),
            .assistantTextDelta(let s, _),
            .assistantThinkingDelta(let s, _),
            .plan(let s, _, _, _, _),
            .assistantFinal(let s, _, _, _, _, _, _),
            .toolResults(let s, _), .toolOutputDelta(let s, _, _), .toolResult(let s, _, _, _), .result(let s, _, _),
            .aborted(let s),
            .exited(let s, _),
            .error(let s, _), .compacting(let s), .replay(let s), .unknown(let s):
            return s
        }
    }

    static func decode(_ data: Data) -> ChatStreamEvent? {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let seq = obj["seq"] as? Int
        {
            if let event = decodeEnvelopeEvent(obj: obj, seq: seq) { return event }
            if let event = decodeClaudeEvent(obj: obj, seq: seq) { return event }
            return .unknown(seq: seq)
        }
        return nil
    }

    private static func decodeEnvelopeEvent(obj: [String: Any], seq: Int) -> ChatStreamEvent? {
        if let type = obj["type"] as? String {
            if type == "usage" {
                return .usage(
                    seq: seq, contextTokens: obj["contextTokens"] as? Int, contextWindow: obj["contextWindow"] as? Int)
            }
            if type == "session", let threadId = obj["threadId"] as? String {
                return .sessionMetadata(seq: seq, threadId: threadId)
            }
            if type == "request", let requestId = obj["requestId"] as? String, let method = obj["method"] as? String {
                return .request(
                    seq: seq,
                    interaction: ChatInteraction(
                        id: requestId, method: method, paramsJSON: ChatToolCall.prettyJSON(obj["params"] ?? [:])))
            }
            if type == "agent_attention", let threadId = obj["threadId"] as? String,
                let requestId = obj["requestId"] as? String, let pending = obj["pending"] as? Bool,
                !threadId.isEmpty && !requestId.isEmpty
            {
                return .agentAttention(seq: seq, threadId: threadId, requestId: requestId, pending: pending)
            }
            if type == "request_resolved", let requestId = obj["requestId"] as? String {
                return .requestResolved(seq: seq, requestId: requestId)
            }
            if type == "tool_output_delta", let id = obj["toolUseId"] as? String, let text = obj["text"] as? String {
                return .toolOutputDelta(seq: seq, toolUseId: id, text: text)
            }
            if type == "aborted" { return .aborted(seq: seq) }
            if type == "exit" { return .exited(seq: seq, code: obj["code"] as? Int ?? 0) }
            if type == "error" {
                return .error(seq: seq, message: obj["message"] as? String ?? "unknown")
            }
            if type == "status", obj["state"] as? String == "compacting" {
                return .compacting(seq: seq)
            }
            if type == "replay" { return .replay(seq: seq) }
        }
        return nil
    }

    private static func decodeClaudeEvent(obj: [String: Any], seq: Int) -> ChatStreamEvent? {
        if let event = obj["event"] as? [String: Any], let eventType = event["type"] as? String {
            if eventType == "plan", let itemId = event["itemId"] as? String, !itemId.isEmpty,
                let text = event["text"] as? String, let delta = event["delta"] as? Bool,
                let completed = event["completed"] as? Bool
            {
                return .plan(seq: seq, itemId: itemId, text: text, delta: delta, completed: completed)
            }
            if eventType == "system" { return .initialized(seq: seq, model: event["model"] as? String) }
            if eventType == "stream_event" { return decodeStreamEvent(event: event, seq: seq) }
            if eventType == "assistant" { return decodeAssistant(event: event, seq: seq) }
            if eventType == "user" { return decodeToolResult(event: event, seq: seq) }
            if eventType == "result" {
                let cost = event["total_cost_usd"] as? Double
                let windows = ((event["modelUsage"] as? [String: Any]) ?? [:]).values
                    .compactMap { ($0 as? [String: Any])?["contextWindow"] as? Int }
                return .result(seq: seq, costUsd: cost, contextWindow: windows.max())
            }
        }
        return nil
    }

    private static func decodeStreamEvent(event: [String: Any], seq: Int) -> ChatStreamEvent? {
        if let inner = event["event"] as? [String: Any] {
            let innerType = inner["type"] as? String
            if innerType == "content_block_start",
                (inner["content_block"] as? [String: Any])?["type"] as? String == "thinking"
            {
                return .assistantThinkingDelta(seq: seq, text: "")
            }
            if innerType == "content_block_delta", let delta = inner["delta"] as? [String: Any] {
                if delta["type"] as? String == "text_delta", let text = delta["text"] as? String {
                    return .assistantTextDelta(seq: seq, text: text)
                }
                if delta["type"] as? String == "thinking_delta" {
                    return .assistantThinkingDelta(
                        seq: seq, text: delta["thinking"] as? String ?? delta["text"] as? String ?? "")
                }
            }
        }
        return nil
    }

    private static func decodeAssistant(event: [String: Any], seq: Int) -> ChatStreamEvent? {
        if let message = event["message"] as? [String: Any],
            let content = message["content"] as? [[String: Any]]
        {
            let parentToolUseId = event["parent_tool_use_id"] as? String
            var text = ""
            var thinking = ""
            var redacted = false
            var toolUses: [DecodedToolUse] = []
            for block in content {
                let type = block["type"] as? String
                if type == "text", let t = block["text"] as? String { text += t }
                if type == "thinking", let t = block["thinking"] as? String { thinking += t }
                if type == "redacted_thinking" { redacted = true }
                if type == "tool_use",
                    let id = block["id"] as? String, let name = block["name"] as? String
                {
                    let input = (block["input"] as? [String: Any]) ?? [:]
                    toolUses.append(
                        DecodedToolUse(
                            id: id,
                            name: name,
                            inputSummary: ChatToolCall.summarize(name: name, input: input),
                            inputJSON: ChatToolCall.prettyJSON(input),
                            parentToolUseId: parentToolUseId
                        )
                    )
                }
            }
            let model = message["model"] as? String
            return .assistantFinal(
                seq: seq, text: text, thinking: thinking, thinkingRedacted: redacted,
                toolUses: toolUses, model: model,
                contextTokens: contextTokens(message: message))
        }
        return nil
    }

    private static func contextTokens(message: [String: Any]) -> Int? {
        if let usage = message["usage"] as? [String: Any] {
            let total = ["input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"]
                .compactMap { usage[$0] as? Int }.reduce(0, +)
            return total > 0 ? total : nil
        }
        return nil
    }

    private static func decodeToolResult(event: [String: Any], seq: Int) -> ChatStreamEvent? {
        if let message = event["message"] as? [String: Any], let content = message["content"] as? [[String: Any]] {
            let results = content.filter { $0["type"] as? String == "tool_result" }.compactMap {
                block -> ChatToolResult? in
                if let id = block["tool_use_id"] as? String {
                    return ChatToolResult(
                        id: id, text: extractToolResultText(block: block), isError: block["is_error"] as? Bool ?? false)
                }
                return nil
            }
            if results.count > 1 { return .toolResults(seq: seq, results: results) }
            if let result = results.first {
                return .toolResult(seq: seq, toolUseId: result.id, text: result.text, isError: result.isError)
            }
        }
        return nil
    }

    private static func extractToolResultText(block: [String: Any]) -> String {
        if let s = block["content"] as? String { return s }
        if let blocks = block["content"] as? [[String: Any]] {
            return blocks.compactMap { $0["text"] as? String }.joined(separator: "\n")
        }
        return ""
    }
}
