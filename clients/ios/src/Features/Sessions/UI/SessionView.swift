import SwiftData
import SwiftUI

struct SessionView: View {
    @Bindable var session: Session
    @Binding var isSidebarOpen: Bool
    @Binding var folderPickerRequest: SessionFolderPickerRequest?

    var body: some View {
        ZStack {
            if session.isConfigured {
                ChatView(session: session, folderPickerRequest: $folderPickerRequest)
                    .opacity(session.tab == .chat ? 1 : 0)
                    .allowsHitTesting(session.tab == .chat)
                FileTreeView(session: session)
                    .opacity(session.tab == .files ? 1 : 0)
                    .allowsHitTesting(session.tab == .files)
                GitView(session: session)
                    .opacity(session.tab == .git ? 1 : 0)
                    .allowsHitTesting(session.tab == .git)
            } else {
                ChatView(session: session, folderPickerRequest: $folderPickerRequest)
            }
        }
        .safeAreaInset(edge: .top) {
            HStack(spacing: ThemeTokens.Spacing.s) {
                IconPillButton(symbol: "line.3.horizontal") {
                    withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) {
                        isSidebarOpen = true
                    }
                }
                Spacer(minLength: 0)
                if session.isConfigured {
                    SessionViewTabs(selected: $session.tab, session: session)
                }
            }
            .padding(.horizontal, ThemeTokens.Spacing.m)
        }
    }
}
