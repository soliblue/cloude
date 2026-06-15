import SwiftUI

struct SessionViewHeader: View {
    let selectedTab: SessionTab
    let isGitSelected: Bool
    let sessionId: UUID
    let isConfigured: Bool
    let hasGit: Bool
    let openSidebar: () -> Void
    let selectTab: (SessionTab) -> Void

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.s) {
            SessionsMenuButton(action: openSidebar)
            Spacer(minLength: 0)
            if isConfigured {
                SessionViewTabs(
                    selected: selectedTab,
                    isGitSelected: isGitSelected,
                    sessionId: sessionId,
                    hasGit: hasGit,
                    selectTab: selectTab
                )
            }
        }
        .padding(.horizontal, ThemeTokens.Spacing.m)
    }
}
