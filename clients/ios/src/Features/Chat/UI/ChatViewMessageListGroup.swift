import SwiftUI

struct ChatViewMessageListGroup: View {
    let session: Session
    let messages: [ChatMessage]
    var isLast: Bool = false
    let taskItems: [ChatTodoItem]
    let taskMessageIds: Set<UUID>
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: ThemeTokens.Spacing.s) {
            if role == .user { Spacer(minLength: ThemeTokens.Spacing.xs) }
            if let retryable = retryableUserMessage {
                ChatViewMessageListGroupRetryButton(message: retryable)
            }
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                ForEach(ChatMessageSegment.build(from: messages)) { segment in
                    switch segment {
                    case .message(let message):
                        ChatViewMessageListRow(session: session, message: message)
                            .id(message.id)
                    case .thinking(let run):
                        if run.count == 1 {
                            ChatViewMessageListRow(session: session, message: run[0])
                                .id(run[0].id)
                        } else {
                            ChatViewMessageListRowThinking(
                                text: run.map(\.thinking).filter { !$0.isEmpty }
                                    .joined(separator: "\n\n"),
                                durationMs: run.reduce(0) { $0 + $1.thinkingMs },
                                redacted: run.allSatisfy(\.thinkingRedacted)
                            )
                            .id(run[0].id)
                        }
                    case .tools(let messageIds):
                        ChatViewMessageListRowToolPillList(session: session, messageIds: messageIds)
                    }
                }
                if let status = statusMessage {
                    if let modelId = status.model {
                        ChatViewMessageListGroupStatusRow(modelId: modelId, costUsd: status.costUsd)
                    }
                    ChatViewMessageListGroupGitCard(session: session, messageId: status.id)
                }
                ChatViewMessageListGroupTaskCard(
                    messageIds: messages.map(\.id), taskItems: taskItems, taskMessageIds: taskMessageIds)
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
        guard role == .assistant, !(isLast && session.isStreaming),
            messages.allSatisfy({ $0.state != .streaming })
        else { return nil }
        return messages.last(where: { $0.model != "<synthetic>" })
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

}
