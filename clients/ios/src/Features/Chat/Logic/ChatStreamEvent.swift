import Foundation

struct DecodedToolUse: Equatable {
    let id: String
    let name: String
    let inputSummary: String
    let inputJSON: String
}

enum ChatStreamEvent {
    case initialized(seq: Int)
    case assistantTextDelta(seq: Int, text: String)
    case assistantFinal(seq: Int, text: String, toolUses: [DecodedToolUse])
    case toolResult(seq: Int, toolUseId: String, text: String, isError: Bool)
    case result(seq: Int, costUsd: Double?)
    case aborted(seq: Int)
    case exited(seq: Int, code: Int)
    case error(seq: Int, message: String)
    case unknown(seq: Int)

    var seq: Int {
        switch self {
        case .initialized(let s), .assistantTextDelta(let s, _), .assistantFinal(let s, _, _),
            .toolResult(let s, _, _, _), .result(let s, _), .aborted(let s), .exited(let s, _),
            .error(let s, _), .unknown(let s):
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
            if type == "aborted" { return .aborted(seq: seq) }
            if type == "exit" { return .exited(seq: seq, code: obj["code"] as? Int ?? 0) }
            if type == "error" {
                return .error(seq: seq, message: obj["message"] as? String ?? "unknown")
            }
        }
        return nil
    }

    private static func decodeClaudeEvent(obj: [String: Any], seq: Int) -> ChatStreamEvent? {
        if let event = obj["event"] as? [String: Any], let eventType = event["type"] as? String {
            if eventType == "system" { return .initialized(seq: seq) }
            if eventType == "stream_event" { return decodeStreamEvent(event: event, seq: seq) }
            if eventType == "assistant" { return decodeAssistant(event: event, seq: seq) }
            if eventType == "user" { return decodeToolResult(event: event, seq: seq) }
            if eventType == "result" {
                let cost = event["total_cost_usd"] as? Double
                return .result(seq: seq, costUsd: cost)
            }
        }
        return nil
    }

    private static func decodeStreamEvent(event: [String: Any], seq: Int) -> ChatStreamEvent? {
        if let inner = event["event"] as? [String: Any],
            inner["type"] as? String == "content_block_delta",
            let delta = inner["delta"] as? [String: Any],
            delta["type"] as? String == "text_delta",
            let text = delta["text"] as? String
        {
            return .assistantTextDelta(seq: seq, text: text)
        }
        return nil
    }

    private static func decodeAssistant(event: [String: Any], seq: Int) -> ChatStreamEvent? {
        if let message = event["message"] as? [String: Any],
            let content = message["content"] as? [[String: Any]]
        {
            var text = ""
            var toolUses: [DecodedToolUse] = []
            for block in content {
                let type = block["type"] as? String
                if type == "text", let t = block["text"] as? String { text += t }
                if type == "tool_use",
                    let id = block["id"] as? String, let name = block["name"] as? String
                {
                    let input = (block["input"] as? [String: Any]) ?? [:]
                    toolUses.append(
                        DecodedToolUse(
                            id: id,
                            name: name,
                            inputSummary: ChatToolCall.summarize(name: name, input: input),
                            inputJSON: ChatToolCall.prettyJSON(input)
                        )
                    )
                }
            }
            return .assistantFinal(seq: seq, text: text, toolUses: toolUses)
        }
        return nil
    }

    private static func decodeToolResult(event: [String: Any], seq: Int) -> ChatStreamEvent? {
        if let message = event["message"] as? [String: Any],
            let content = message["content"] as? [[String: Any]]
        {
            for block in content where block["type"] as? String == "tool_result" {
                if let id = block["tool_use_id"] as? String {
                    let isError = block["is_error"] as? Bool ?? false
                    let text = extractToolResultText(block: block)
                    return .toolResult(seq: seq, toolUseId: id, text: text, isError: isError)
                }
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
