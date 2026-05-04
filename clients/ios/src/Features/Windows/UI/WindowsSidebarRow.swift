import SwiftUI

struct WindowsSidebarRow: View {
    let symbol: String
    let title: String
    let isFocused: Bool
    var isStreaming: Bool = false
    var isUnread: Bool = false
    @Environment(\.appAccent) private var appAccent
    @State private var pulse: Bool = false

    var body: some View {
        let highlight = isStreaming || isUnread
        HStack(spacing: ThemeTokens.Spacing.m) {
            Image(systemName: symbol)
                .appFont(size: ThemeTokens.Text.l, weight: .medium)
                .foregroundColor(highlight ? appAccent.color : (isFocused ? .primary : .secondary))
                .frame(width: ThemeTokens.Size.m)
            Text(title)
                .appFont(size: ThemeTokens.Text.l, weight: (isFocused || highlight) ? .medium : .regular)
                .foregroundColor(highlight ? appAccent.color : .primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .opacity(isStreaming && pulse ? 0.4 : 1.0)
        .animation(isStreaming ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : .default, value: pulse)
        .onAppear { if isStreaming { pulse = true } }
        .onChange(of: isStreaming) { _, streaming in
            pulse = streaming
        }
    }
}
