import SwiftUI

struct SessionViewHeader: View {
    let session: Session
    let selectedTab: SessionTab
    let isGitSelected: Bool
    let openSidebar: () -> Void
    let selectTab: (SessionTab) -> Void
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: ThemeTokens.Spacing.s) {
            HStack(spacing: ThemeTokens.Spacing.s) {
                SessionsMenuButton(action: openSidebar)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    Text(
                        [session.endpoint?.displayName, session.path.map { ($0 as NSString).lastPathComponent }]
                            .compactMap { $0 }.joined(separator: " · ")
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                SessionTaskMenu(session: session)
            }
            if session.isConfigured {
                HStack(spacing: ThemeTokens.Spacing.m) {
                    SessionViewTabs(
                        selected: selectedTab, isGitSelected: isGitSelected,
                        sessionId: session.id, hasGit: session.hasGit, selectTab: selectTab)
                    Spacer(minLength: 0)
                    if session.provider == .codex, let endpoint = session.endpoint {
                        SessionAccountButton(endpoint: endpoint)
                    }
                    if session.provider == .codex && session.existsOnServer {
                        SessionForkButton(session: session)
                    }
                }
            }
        }
        .padding(.horizontal, ThemeTokens.Spacing.m)
        .padding(.vertical, ThemeTokens.Spacing.xs)
        .background(theme.palette.background)
    }
}
