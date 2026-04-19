import SwiftUI

extension WorkspaceView {
    @ViewBuilder
    func pagedWindowContent(for window: Window) -> some View {
        let conversation = window.conversation(in: conversationStore)
        let environmentId = window.runtimeEnvironmentId(conversationStore: conversationStore, environmentStore: environmentStore)
        let connection = environmentStore.connection(for: environmentId)

        VStack(spacing: 0) {
            if let connection {
                EnvironmentConnectionObserver(connection: connection) { connection in
                    windowTabBar(window: window, conversation: conversation, connection: connection)
                }
            } else {
                windowTabBar(window: window, conversation: conversation, connection: nil)
            }

            ZStack {
                ConversationView(
                    environmentStore: environmentStore,
                    store: conversationStore,
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
                    environmentStore: environmentStore,
                    rootPath: window.fileBrowserRootPath ?? conversation?.workingDirectory,
                    environmentId: environmentId,
                    isVisible: window.tab == .files,
                    state: windowManager.fileTreeState(for: window.id)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(window.tab == .files ? 1 : 0)
                .allowsHitTesting(window.tab == .files)

                GitChangesView(
                    environmentStore: environmentStore,
                    rootPath: window.gitRepoRootPath ?? conversation?.workingDirectory,
                    environmentId: environmentId,
                    state: windowManager.gitChangesState(for: window.id)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(window.tab == .gitChanges ? 1 : 0)
                .allowsHitTesting(window.tab == .gitChanges)
            }
        }
    }

    private func windowTabBar(window: Window, conversation: Conversation?, connection: EnvironmentConnection?) -> some View {
        WindowTabBar(
            activeTab: window.tab,
            envConnected: (connection?.phase ?? .disconnected) != .disconnected,
            appTheme: appTheme,
            gitStatus: (window.gitRepoRootPath ?? conversation?.workingDirectory).flatMap {
                connection?.git.statusInfo(for: $0)
            },
            folderName: conversation?.workingDirectory.flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0).lastPathComponent },
            totalCost: conversation?.totalCost ?? 0,
            onSelectTab: { tab in withAnimation(.easeInOut(duration: DS.Duration.s)) { windowManager.setWindowTab(window.id, tab: tab) } }
        )
        .equatable()
    }
}
