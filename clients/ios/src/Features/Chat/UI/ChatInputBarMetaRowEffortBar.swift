import SwiftUI

struct ChatInputBarMetaRowEffortBar: View {
    let fraction: Double
    @Environment(\.appAccent) private var appAccent

    var body: some View {
        Capsule()
            .fill(Color.secondary.opacity(ThemeTokens.Opacity.s))
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(appAccent.color)
                    .frame(height: ThemeTokens.Text.m * fraction)
            }
            .frame(width: ThemeTokens.Stroke.l * 2, height: ThemeTokens.Text.m)
    }
}
