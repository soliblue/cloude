import SwiftUI

struct SessionViewTabs: View {
    let selected: SessionTab
    let isGitSelected: Bool
    let sessionId: UUID
    let hasGit: Bool
    let filesLabel: String
    let selectTab: (SessionTab) -> Void
    @Environment(\.appAccent) private var appAccent

    @Namespace private var tabGlass

    var body: some View {
        GlassEffectContainer(spacing: ThemeTokens.Spacing.m) {
            HStack(spacing: ThemeTokens.Spacing.m) {
                ForEach(visibleTabs) { tab in
                    Button {
                        selectTab(tab)
                    } label: {
                        tabContent(tab)
                            .padding(.horizontal, ThemeTokens.Spacing.l)
                            .padding(.vertical, ThemeTokens.Spacing.m)
                            .opacity(isDisabled(tab) ? ThemeTokens.Opacity.m : 1)
                            .glassEffect(.regular, in: Capsule())
                            .glassEffectID(tab, in: tabGlass)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled(tab))
                }
            }
        }
    }

    @ViewBuilder
    private func tabContent(_ tab: SessionTab) -> some View {
        let active = tab == .git ? isGitSelected : !isGitSelected && selected == tab
        if tab == .git {
            SessionViewTabsGitLabel(sessionId: sessionId, isActive: active)
        } else if tab == .chat {
            SessionViewTabsChatLabel(sessionId: sessionId, isActive: active)
        } else {
            HStack(spacing: ThemeTokens.Spacing.xs) {
                Image(systemName: tab.symbol)
                    .appFont(size: ThemeTokens.Text.m, weight: .medium)
                let text = label(for: tab)
                if !text.isEmpty {
                    Text(text)
                        .appFont(size: ThemeTokens.Text.m, weight: .medium)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .foregroundColor(active ? appAccent.color : .secondary)
        }
    }

    private func isDisabled(_ tab: SessionTab) -> Bool {
        tab == .git && !hasGit
    }

    private var visibleTabs: [SessionTab] {
        SessionTab.allCases.filter { $0 != .git || hasGit }
    }

    private func label(for tab: SessionTab) -> String {
        tab == .files ? filesLabel : tab.label
    }
}
