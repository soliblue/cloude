import SwiftUI

struct ChatViewMessageListRowThinking: View {
    let text: String
    let durationMs: Int
    var isLive: Bool = false
    var redacted: Bool = false

    @State private var isExpanded = false
    @State private var phase: CGFloat = -0.7

    var body: some View {
        if isLive {
            live
        } else {
            done
        }
    }

    private var live: some View {
        let label = Text("Thinking").appFont(size: ThemeTokens.Text.s, weight: .medium)
        return label
            .foregroundColor(ThemeColor.secondary)
            .overlay {
                ChatViewMessageListRowToolPillListRowShimmer(phase: phase, tint: .primary)
                    .mask(label)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: false)) {
                    phase = 1.1
                }
            }
    }

    @ViewBuilder private var done: some View {
        let canExpand = !redacted && !text.isEmpty
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
            Button {
                withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: ThemeTokens.Spacing.xs) {
                    Image(systemName: redacted ? "lock.fill" : "brain")
                        .appFont(size: ThemeTokens.Text.s)
                    Text(durationLabel)
                        .appFont(size: ThemeTokens.Text.s, weight: .medium)
                    if canExpand {
                        Image(systemName: "chevron.right")
                            .appFont(size: ThemeTokens.Text.s, weight: .semibold)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
                .foregroundColor(ThemeColor.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canExpand)
            if isExpanded {
                Text(text)
                    .appFont(size: ThemeTokens.Text.s)
                    .foregroundColor(ThemeColor.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.leading, ThemeTokens.Spacing.s)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(ThemeColor.secondary.opacity(ThemeTokens.Opacity.s))
                            .frame(width: ThemeTokens.Stroke.l)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var durationLabel: String {
        if durationMs <= 0 { return "Thought" }
        return "Thought for \(max(1, Int((Double(durationMs) / 1000).rounded())))s"
    }
}
