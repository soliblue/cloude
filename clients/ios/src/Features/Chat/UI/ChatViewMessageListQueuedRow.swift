import SwiftUI

struct ChatViewMessageListQueuedRow: View {
    let message: ChatMessage
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(alignment: .center, spacing: ThemeTokens.Spacing.s) {
            Spacer(minLength: ThemeTokens.Spacing.xs)
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                if !message.imagesData.isEmpty {
                    ChatViewMessageListRowAttachmentList(images: message.imagesData)
                }
                Text(message.text)
                    .appFont(size: ThemeTokens.Text.m)
            }
            .padding(.horizontal, ThemeTokens.Spacing.m)
            .padding(.vertical, ThemeTokens.Spacing.s)
            .background(theme.palette.surface)
            .clipShape(bubbleShape)
            .opacity(ThemeTokens.Opacity.l)
            .contextMenu {
                Button(role: .destructive) {
                    ChatActions.removeQueued(message, context: context)
                } label: {
                    Label("Remove from Queue", systemImage: "trash")
                }
            }
        }
    }

    private var bubbleShape: UnevenRoundedRectangle {
        let r = ThemeTokens.Radius.m
        return UnevenRoundedRectangle(
            topLeadingRadius: r,
            bottomLeadingRadius: r,
            bottomTrailingRadius: 0,
            topTrailingRadius: 0
        )
    }
}
