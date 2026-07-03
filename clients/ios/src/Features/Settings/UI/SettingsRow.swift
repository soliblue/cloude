import SwiftUI

struct SettingsRow<Content: View>: View {
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.m) {
            Image(systemName: icon)
                .appFont(size: ThemeTokens.Text.l, weight: .medium)
                .foregroundColor(color)
                .frame(width: ThemeTokens.Size.m)
            content
                .appFont(size: ThemeTokens.Text.l)
        }
    }
}
