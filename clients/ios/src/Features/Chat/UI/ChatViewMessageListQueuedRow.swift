import SwiftUI

struct ChatViewMessageListQueuedRow: View {
    let message: ChatMessage
    let provider: ChatProvider
    @State private var steerFailed = false
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(alignment: .center, spacing: ThemeTokens.Spacing.s) {
            Spacer(minLength: ThemeTokens.Spacing.xs)
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                if !message.imagesData.isEmpty {
                    ChatViewMessageListRowAttachmentList(images: message.imagesData)
                }
                Label("Queued", systemImage: "clock").font(.caption).foregroundStyle(.secondary)
                Text(message.text)
                    .appFont(size: ThemeTokens.Text.m)
            }
            .padding(.horizontal, ThemeTokens.Spacing.m)
            .padding(.vertical, ThemeTokens.Spacing.s)
            .background(theme.palette.surface)
            .clipShape(bubbleShape)
            .opacity(ThemeTokens.Opacity.l)
            .alert("Could not steer the active turn", isPresented: $steerFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your message remains queued for the next turn.")
            }
            .contextMenu {
                if provider == .codex && message.imagesData.isEmpty && message.references.isEmpty
                    && message.reviewTarget == nil && message.shellCommand == nil
                {
                    Button {
                        Task { steerFailed = !(await ChatService.steer(message: message, context: context)) }
                    } label: {
                        Label("Send to active turn", systemImage: "arrow.turn.up.right")
                    }
                }
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
