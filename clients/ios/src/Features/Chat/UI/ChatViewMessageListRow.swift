import SwiftUI

struct ChatViewMessageListRow: View {
    let message: ChatMessage
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: ThemeTokens.Spacing.s) {
            if message.role == .user { Spacer(minLength: ThemeTokens.Size.m) }
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                if !message.imagesData.isEmpty {
                    ChatViewMessageListRowAttachmentList(images: message.imagesData)
                }
                content
                if !message.orderedToolCalls.isEmpty {
                    ChatViewMessageListRowToolPillList(toolCalls: message.orderedToolCalls)
                }
                if message.state == .failed {
                    Text("Failed")
                        .appFont(size: ThemeTokens.Text.s)
                        .foregroundColor(ThemeColor.danger)
                }
            }
            .padding(.horizontal, ThemeTokens.Spacing.m)
            .padding(.vertical, ThemeTokens.Spacing.s)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.m))
            if message.role == .assistant { Spacer(minLength: ThemeTokens.Size.m) }
        }
    }

    @ViewBuilder private var content: some View {
        if message.text.isEmpty && message.state == .streaming && message.orderedToolCalls.isEmpty {
            ProgressView().controlSize(.small)
        } else if !message.text.isEmpty {
            if message.role == .assistant && message.state != .streaming {
                ChatViewMessageListRowMarkdown(text: message.text)
            } else {
                Text(message.text)
                    .appFont(size: ThemeTokens.Text.m)
                    .textSelection(.enabled)
            }
        }
    }

    private var background: Color {
        message.role == .user ? theme.palette.elevated : theme.palette.surface
    }
}
