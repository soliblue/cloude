import SwiftUI

struct ChatViewMessageListGroup: View {
    let session: Session
    let messages: [ChatMessage]
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: ThemeTokens.Spacing.s) {
            if role == .user { Spacer(minLength: ThemeTokens.Spacing.xs) }
            if let retryable = retryableUserMessage {
                ChatViewMessageListGroupRetryButton(message: retryable)
            }
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    switch segment {
                    case .message(let message):
                        ChatViewMessageListRow(session: session, message: message)
                            .id(message.id)
                    case .tools(let messageIds):
                        ChatViewMessageListRowToolPillList(session: session, messageIds: messageIds)
                    }
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
                !message.imagesData.isEmpty || !message.text.isEmpty
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

    private enum Segment {
        case message(ChatMessage)
        case tools([UUID])
    }
}
