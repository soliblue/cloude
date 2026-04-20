import SwiftData
import SwiftUI

struct WindowsViewSwitcherPill: View {
    let window: Window
    let session: Session
    let windows: [Window]
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.xs) {
            Image(systemName: session.symbol)
                .appFont(size: ThemeTokens.Icon.s)
            Text(session.title)
                .appFont(size: ThemeTokens.Text.m, weight: .medium)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: ThemeTokens.Size.xl)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, ThemeTokens.Spacing.m)
        .padding(.vertical, ThemeTokens.Spacing.s)
        .foregroundColor(window.isFocused ? Color.accentColor : .secondary)
        .background(
            window.isFocused
                ? Color.accentColor.opacity(ThemeTokens.Opacity.s) : theme.palette.surface
        )
        .clipShape(Capsule())
        .onTapGesture { WindowActions.activate(window, among: windows) }
        .onLongPressGesture { WindowActions.close(window, among: windows, context: context) }
    }
}
