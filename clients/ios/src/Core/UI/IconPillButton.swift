import SwiftUI

struct IconPillButton: View {
    @Environment(\.theme) private var theme
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .appFont(size: ThemeTokens.Text.m, weight: .medium)
                .padding(.horizontal, ThemeTokens.Spacing.m)
                .padding(.vertical, ThemeTokens.Spacing.s)
                .foregroundColor(.secondary)
                .background(theme.palette.surface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
