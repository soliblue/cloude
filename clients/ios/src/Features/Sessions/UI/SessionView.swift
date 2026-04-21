import SwiftData
import SwiftUI

struct SessionView: View {
    let session: Session
    @State private var activeTab: SessionTab = .chat

    var body: some View {
        if session.endpoint == nil || (session.path ?? "").isEmpty {
            SessionEmptyView(session: session)
        } else {
            Group {
                if activeTab == .files {
                    FileTreeView(session: session)
                } else {
                    VStack(spacing: ThemeTokens.Spacing.m) {
                        Image(systemName: "hammer.fill")
                            .appFont(size: ThemeTokens.Icon.l)
                            .foregroundColor(.secondary)
                        Text("\(activeTab.label) coming soon")
                            .appFont(size: ThemeTokens.Text.m)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .safeAreaInset(edge: .top) {
                SessionViewTabs(selected: $activeTab)
                    .padding(.horizontal, ThemeTokens.Spacing.m)
                    .padding(.vertical, ThemeTokens.Spacing.s)
            }
        }
    }
}
