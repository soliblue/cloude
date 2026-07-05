import SwiftUI

struct WindowsSidebarOpenRow: View {
    let session: Session
    let isFocused: Bool
    let canClose: Bool
    let onActivate: () -> Void
    let onClose: () -> Void
    @Environment(\.appAccent) private var appAccent

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.s) {
            WindowsSidebarRow(
                symbol: session.symbol,
                title: session.title,
                isFocused: isFocused,
                isStreaming: session.isStreaming,
                isUnread: isUnread,
                endpointName: session.endpoint?.displayName,
                path: session.path
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: onActivate)
            Spacer(minLength: 0)
            if canClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .appFont(size: ThemeTokens.Text.m, weight: .medium)
                        .foregroundColor(ThemeColor.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, ThemeTokens.Spacing.l)
        .padding(.vertical, ThemeTokens.Spacing.s)
        .background(isFocused ? appAccent.color.opacity(0.15) : Color.clear)
        .padding(.horizontal, -ThemeTokens.Spacing.l)
    }

    private var isUnread: Bool {
        !isFocused && session.hasUnread
    }
}
