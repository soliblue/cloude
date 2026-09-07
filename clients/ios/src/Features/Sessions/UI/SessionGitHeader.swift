import SwiftUI

struct SessionGitHeader: View {
    let openSidebar: () -> Void
    let openChat: () -> Void

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.s) {
            SessionsMenuButton(action: openSidebar)
            Spacer(minLength: ThemeTokens.Spacing.s)
            IconPillButton(symbol: "bubble.left", action: openChat)
                .accessibilityLabel("Return to chat")
        }
        .padding(.horizontal, ThemeTokens.Spacing.m)
    }
}
