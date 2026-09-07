import SwiftUI

struct SessionViewHeader: View {
    let session: Session
    let selectedTab: SessionTab
    let isGitSelected: Bool
    let openSidebar: () -> Void
    let selectTab: (SessionTab) -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.m) {
            SessionsMenuButton(action: openSidebar)
            Spacer(minLength: 0)
            if session.isConfigured {
                SessionViewTabs(
                    selected: selectedTab, isGitSelected: isGitSelected,
                    sessionId: session.id, hasGit: session.hasGit, selectTab: selectTab)
            }
        }
        .padding(.horizontal, ThemeTokens.Spacing.m)
        .padding(.vertical, ThemeTokens.Spacing.xs)
        .background(theme.palette.background)
    }
}
