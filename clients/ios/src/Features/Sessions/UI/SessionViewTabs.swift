import SwiftUI

struct SessionViewTabs: View {
    @Binding var selected: SessionTab
    let session: Session
    @Environment(\.theme) private var theme
    @Environment(\.appAccent) private var appAccent

    private static let maxNameLength = 10

    @Namespace private var tabGlass

    var body: some View {
        GlassEffectContainer(spacing: ThemeTokens.Spacing.m) {
            HStack(spacing: ThemeTokens.Spacing.m) {
                ForEach(visibleTabs) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) {
                            selected = tab
                        }
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
        let active = selected == tab
        if tab == .git {
            SessionViewTabsGitLabel(session: session, isActive: active)
        } else if tab == .chat {
            SessionViewTabsChatLabel(session: session, isActive: active)
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
        tab == .git && !session.hasGit
    }

    private var visibleTabs: [SessionTab] {
        SessionTab.allCases.filter { $0 != .git || session.hasGit }
    }

    private func label(for tab: SessionTab) -> String {
        if tab == .files, let path = session.path, !path.isEmpty {
            let leaf = (path as NSString).lastPathComponent
            return leaf.count > Self.maxNameLength
                ? String(leaf.prefix(Self.maxNameLength)) + "…"
                : leaf
        }
        return tab.label
    }
}
