import SwiftUI

struct SessionViewHeader: View {
    @Binding var isSidebarOpen: Bool
    @Binding var selectedTab: SessionTab
    let sessionId: UUID
    let isConfigured: Bool
    let hasGit: Bool
    let filesLabel: String

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.s) {
            IconPillButton(symbol: "line.3.horizontal") {
                withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) {
                    isSidebarOpen = true
                }
            }
            Spacer(minLength: 0)
            if isConfigured {
                SessionViewTabs(
                    selected: $selectedTab,
                    sessionId: sessionId,
                    hasGit: hasGit,
                    filesLabel: filesLabel
                )
            }
        }
        .padding(.horizontal, ThemeTokens.Spacing.m)
    }
}
