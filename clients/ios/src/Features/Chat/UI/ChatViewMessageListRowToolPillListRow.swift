import SwiftUI

struct ChatViewMessageListRowToolPillListRow: View {
    let toolCall: ChatToolCall
    var onTap: () -> Void
    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        let tint = toolCall.kind.color
        Button(action: onTap) {
            HStack(spacing: ThemeTokens.Spacing.xs) {
                Image(systemName: toolCall.symbol)
                    .appFont(size: ThemeTokens.Text.s)
                Text(toolCall.shortLabel)
                    .appFont(size: ThemeTokens.Text.s)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .foregroundColor(tint)
            .padding(.horizontal, ThemeTokens.Spacing.s)
            .padding(.vertical, ThemeTokens.Spacing.xs)
            .glassEffect(.regular.interactive(), in: Capsule())
            .overlay {
                if toolCall.state == .pending {
                    ChatViewMessageListRowToolPillListRowShimmer(phase: shimmerPhase, tint: tint)
                        .clipShape(Capsule())
                        .transition(.opacity)
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            if toolCall.state == .pending {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    shimmerPhase = 1.5
                }
            }
        }
        .onChange(of: toolCall.state) { _, newState in
            if newState != .pending {
                withAnimation(.easeOut(duration: 0.2)) { shimmerPhase = -1 }
            }
        }
    }
}
