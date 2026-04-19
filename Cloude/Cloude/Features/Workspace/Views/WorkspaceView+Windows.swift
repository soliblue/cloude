import SwiftUI

extension WorkspaceView {
    @ViewBuilder
    func pagedWindowContent(for window: Window) -> some View {
        let conversation = window.conversation(in: conversationStore)

        VStack(spacing: 0) {
            WindowTabBar(
                activeTab: window.tab,
                envConnected: ((conversation?.environmentId).flatMap { connection.connection(for: $0)?.phase } ?? .disconnected) != .disconnected,
                connection: connection,
                appTheme: appTheme,
                repoPath: window.gitRepoRootPath ?? conversation?.workingDirectory,
                environmentId: conversation?.environmentId,
                folderName: conversation?.workingDirectory.flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0).lastPathComponent },
                totalCost: conversation?.totalCost ?? 0,
                onSelectTab: { tab in withAnimation(.easeInOut(duration: DS.Duration.s)) { windowManager.setWindowTab(window.id, tab: tab) } }
            )
            .equatable()

            ZStack {
                ConversationView(
                    connection: connection,
                    store: conversationStore,
                    environmentStore: environmentStore,
                    conversation: conversation,
                    window: window,
                    windowManager: windowManager,
                    onInteraction: { dismissKeyboard() },
                    onSelectRecentConversation: { conv in
                        windowManager.linkToCurrentConversation(window.id, conversation: conv)
                    },
                    onSeeAllConversations: {
                        store.openConversationSearch()
                    }
                )
                .id(window.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(window.tab == .chat ? 1 : 0)
                .allowsHitTesting(window.tab == .chat)

                FileTreeView(
                    connection: connection,
                    rootPath: window.fileBrowserRootPath ?? conversation?.workingDirectory,
                    environmentId: conversation?.environmentId,
                    isVisible: window.tab == .files,
                    state: windowManager.fileTreeState(for: window.id)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(window.tab == .files ? 1 : 0)
                .allowsHitTesting(window.tab == .files)

                GitChangesView(
                    connection: connection,
                    rootPath: window.gitRepoRootPath ?? conversation?.workingDirectory,
                    environmentId: conversation?.environmentId,
                    state: windowManager.gitChangesState(for: window.id)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(window.tab == .gitChanges ? 1 : 0)
                .allowsHitTesting(window.tab == .gitChanges)
            }
        }
    }
}
