import SwiftUI

struct WindowsSidebarRow: View {
    let symbol: String
    let title: String
    let isFocused: Bool
    @Environment(\.appAccent) private var appAccent

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.m) {
            Image(systemName: symbol)
                .appFont(size: ThemeTokens.Text.l, weight: .medium)
                .foregroundColor(isFocused ? appAccent.color : .secondary)
                .frame(width: ThemeTokens.Size.m)
            Text(title)
                .appFont(size: ThemeTokens.Text.l, weight: isFocused ? .medium : .regular)
                .foregroundColor(isFocused ? appAccent.color : .primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}
