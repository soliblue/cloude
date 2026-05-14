import SwiftUI

struct ChatViewMessageListRowCompactingPill: View {
    @State private var isSpinning = false

    var body: some View {
        let tint = ThemeColor.cyan
        HStack(spacing: ThemeTokens.Spacing.xs) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .appFont(size: ThemeTokens.Text.s)
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                .animation(
                    .linear(duration: 1.5).repeatForever(autoreverses: false),
                    value: isSpinning
                )
            Text("Compacting")
                .appFont(size: ThemeTokens.Text.s)
        }
        .foregroundColor(.white)
        .padding(.horizontal, ThemeTokens.Spacing.s)
        .padding(.vertical, ThemeTokens.Spacing.xs)
        .glassEffect(
            .regular.tint(tint.opacity(ThemeTokens.Opacity.m)).interactive(),
            in: Capsule()
        )
        .onAppear { isSpinning = true }
    }
}
