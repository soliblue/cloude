import SwiftUI

struct SessionGitHeader: View {
    let session: Session
    let openSidebar: () -> Void
    let openChat: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.s) {
            SessionsMenuButton(action: openSidebar)
            VStack(alignment: .leading, spacing: 2) {
                Text("Git").font(.system(size: 15, weight: .semibold))
                if let endpoint = session.endpoint {
                    Text(endpoint.displayName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: ThemeTokens.Spacing.s)
            Button("Chat", systemImage: "bubble.left", action: openChat)
                .font(.subheadline.weight(.medium))
                .frame(minHeight: 44)
                .accessibilityLabel("Return to chat")
                .accessibilityHint("Open the conversation for this task")
        }
        .padding(.horizontal, ThemeTokens.Spacing.m)
        .padding(.vertical, ThemeTokens.Spacing.xs)
        .background(theme.palette.background)
    }
}
