import SwiftUI

struct SettingsRow<Content: View>: View {
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    @ScaledMetric(relativeTo: .body) private var iconColumnWidth = ThemeTokens.Size.m

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.m) {
            Image(systemName: icon)
                .appFont(size: ThemeTokens.Text.l, weight: .medium)
                .foregroundColor(color)
                .fixedSize()
                .frame(minWidth: iconColumnWidth)
                .accessibilityHidden(true)
            content
                .appFont(size: ThemeTokens.Text.l)
        }
    }
}
