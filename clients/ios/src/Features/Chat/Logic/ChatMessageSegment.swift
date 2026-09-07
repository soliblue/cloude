import Foundation

enum ChatMessageSegment: Identifiable {
    case message(ChatMessage)
    case thinking([ChatMessage])
    case tools([UUID])

    var id: String {
        switch self {
        case .message(let message): "message-\(message.id.uuidString)"
        case .thinking(let run): "thinking-\(run.first?.id.uuidString ?? "")"
        case .tools(let ids): "tools-\(ids.first?.uuidString ?? "")"
        }
    }

    static func build(from messages: [ChatMessage]) -> [ChatMessageSegment] {
        var result: [ChatMessageSegment] = []
        var tools: [UUID] = []
        var thinking: [ChatMessage] = []
        for message in messages {
            let hasContent =
                !message.imagesData.isEmpty || !message.text.isEmpty || message.hasThinking
                || message.state == .streaming || message.state == .failed || message.state == .retrying
            if hasContent {
                if !tools.isEmpty {
                    result.append(.tools(tools))
                    tools = []
                }
                if message.hasThinking && message.text.isEmpty && message.imagesData.isEmpty
                    && message.state != .streaming && message.state != .failed && message.state != .retrying
                {
                    thinking.append(message)
                } else {
                    if !thinking.isEmpty {
                        result.append(.thinking(thinking))
                        thinking = []
                    }
                    result.append(.message(message))
                }
            }
            if message.hasToolCalls {
                if !thinking.isEmpty {
                    result.append(.thinking(thinking))
                    thinking = []
                }
                tools.append(message.id)
            }
        }
        if !thinking.isEmpty { result.append(.thinking(thinking)) }
        if !tools.isEmpty { result.append(.tools(tools)) }
        return result
    }
}
