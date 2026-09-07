import SwiftUI

struct ChatViewMessageListQueuedRow: View {
    let message: ChatMessage
    let provider: ChatProvider
    @State private var steerFailed = false
    @State private var checkingDelivery = false
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(alignment: .center, spacing: ThemeTokens.Spacing.s) {
            Spacer(minLength: ThemeTokens.Spacing.xs)
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                if !message.imagesData.isEmpty {
                    ChatViewMessageListRowAttachmentList(images: message.imagesData)
                }
                Label(message.steerRequestScope == nil ? "Queued" : "Delivery unconfirmed", systemImage: "clock")
                    .font(.caption).foregroundStyle(.secondary)
                Text(message.text)
                    .appFont(size: ThemeTokens.Text.m)
            }
            .padding(.horizontal, ThemeTokens.Spacing.m)
            .padding(.vertical, ThemeTokens.Spacing.s)
            .background(theme.palette.surface)
            .clipShape(bubbleShape)
            .opacity(ThemeTokens.Opacity.l)
            .alert(
                message.steerRequestScope == nil ? "Could not send to the active turn" : "Delivery not confirmed",
                isPresented: $steerFailed
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(
                    message.steerRequestScope == nil
                        ? "Start an active Codex turn before sending this message."
                        : "Reconnect and check delivery again, or inspect the task history. Update the daemon if delivery checks are unavailable. This message stays out of the automatic queue."
                )
            }
            .contextMenu {
                if provider == .codex && message.imagesData.isEmpty && message.references.isEmpty
                    && message.reviewTarget == nil && message.shellCommand == nil
                {
                    Button {
                        Task {
                            checkingDelivery = true
                            steerFailed = !(await ChatService.steer(message: message, context: context))
                            checkingDelivery = false
                        }
                    } label: {
                        Label(
                            message.steerRequestScope == nil ? "Send to active turn" : "Check delivery",
                            systemImage: "arrow.turn.up.right")
                    }
                    .disabled(checkingDelivery)
                }
                Button(role: .destructive) {
                    ChatActions.removeQueued(message, context: context)
                } label: {
                    Label(
                        message.steerRequestScope == nil ? "Remove from Queue" : "Dismiss delivery check",
                        systemImage: "trash")
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
