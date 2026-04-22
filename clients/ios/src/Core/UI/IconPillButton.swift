import SwiftUI

struct IconPillButton: View {
    @Environment(\.theme) private var theme
    let symbol: String
    var tint: Color = .secondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(Image(systemName: symbol))
                .appFont(size: ThemeTokens.Text.m, weight: .medium)
                .foregroundColor(tint)
                .padding(ThemeTokens.Spacing.m)
                .contentShape(Capsule())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
    }
}
