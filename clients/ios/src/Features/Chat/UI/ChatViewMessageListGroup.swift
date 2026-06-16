import SwiftUI

struct ChatViewMessageListGroup: View {
    let session: Session
    let messages: [ChatMessage]
    var isStreamingLastGroup = false
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: ThemeTokens.Spacing.s) {
            if role == .user { Spacer(minLength: ThemeTokens.Spacing.xs) }
            if let retryable = retryableUserMessage {
                ChatViewMessageListGroupRetryButton(message: retryable)
            }
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                ForEach(segments) { segment in
                    switch segment {
                    case .message(let message):
                        ChatViewMessageListRow(session: session, message: message)
                            .id(message.id)
                    case .tools(let messageIds):
                        ChatViewMessageListRowToolPillList(session: session, messageIds: messageIds)
                    }
                }
                if let status = statusMessage, let modelId = status.model {
                    ChatViewMessageListGroupStatusRow(modelId: modelId, costUsd: status.costUsd)
                    ChatViewMessageListGroupGitCard(session: session, messageId: status.id)
                }
            }
            .padding(.horizontal, ThemeTokens.Spacing.m)
            .padding(.vertical, role == .user ? ThemeTokens.Spacing.s : 0)
            .background(role == .user ? theme.palette.surface : Color.clear)
            .clipShape(bubbleShape)
            .frame(maxWidth: role == .assistant ? .infinity : nil, alignment: .leading)
        }
    }

    private var role: ChatMessage.Role {
        messages.first?.role ?? .assistant
    }

    private var statusMessage: ChatMessage? {
        guard role == .assistant, !isStreamingLastGroup,
            messages.allSatisfy({ $0.state != .streaming })
        else { return nil }
        return messages.last(where: { $0.model != nil && $0.model != "<synthetic>" })
    }

    private var retryableUserMessage: ChatMessage? {
        guard role == .user else { return nil }
        return messages.first(where: { $0.state == .failed || $0.state == .retrying })
    }

    private var bubbleShape: UnevenRoundedRectangle {
        let r = ThemeTokens.Radius.m
        return UnevenRoundedRectangle(
            topLeadingRadius: role == .user ? r : 0,
            bottomLeadingRadius: role == .user ? r : 0,
            bottomTrailingRadius: role == .assistant ? r : 0,
            topTrailingRadius: role == .assistant ? r : 0
        )
    }

    private var segments: [Segment] {
        var result: [Segment] = []
        var toolBucket: [UUID] = []
        for message in messages {
            let hasContent =
                !message.imagesData.isEmpty || !message.text.isEmpty || message.hasThinking
                || message.state == .streaming || message.state == .failed
                || message.state == .retrying
            if hasContent {
                if !toolBucket.isEmpty {
                    result.append(.tools(toolBucket))
                    toolBucket = []
                }
                result.append(.message(message))
            }
            if message.hasToolCalls { toolBucket.append(message.id) }
        }
        if !toolBucket.isEmpty { result.append(.tools(toolBucket)) }
        return result
    }

    private enum Segment: Identifiable {
        case message(ChatMessage)
        case tools([UUID])

        var id: String {
            switch self {
            case .message(let message): return "message-\(message.id.uuidString)"
            case .tools(let messageIds): return "tools-\(messageIds.first?.uuidString ?? "")"
            }
        }
    }
}
