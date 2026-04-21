import SwiftData
import SwiftUI

struct SessionView: View {
    @Bindable var session: Session

    var body: some View {
        if session.endpoint == nil || (session.path ?? "").isEmpty {
            SessionEmptyView(session: session)
        } else {
            Group {
                switch session.tab {
                case .chat: ChatView(session: session)
                case .files: FileTreeView(session: session)
                case .git:
                    VStack(spacing: ThemeTokens.Spacing.m) {
                        Image(systemName: "hammer.fill")
                            .appFont(size: ThemeTokens.Icon.l)
                            .foregroundColor(.secondary)
                        Text("\(session.tab.label) coming soon")
                            .appFont(size: ThemeTokens.Text.m)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .safeAreaInset(edge: .top) {
                SessionViewTabs(selected: $session.tab)
                    .padding(.horizontal, ThemeTokens.Spacing.m)
                    .padding(.vertical, ThemeTokens.Spacing.s)
            }
        }
    }
}
