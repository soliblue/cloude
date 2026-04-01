import SwiftUI

extension WorkspaceView {
    @ViewBuilder
    func pagedWindowContent(for window: Window) -> some View {
        let conversation = window.conversation(in: conversationStore)

        VStack(spacing: 0) {
            WindowTabBar(
                activeTab: window.tab,
                envConnected: (conversation?.environmentId).flatMap({ connection.connection(for: $0)?.isConnected }) ?? false,
                connection: connection,
                repoPath: window.gitRepoRootPath ?? gitRepoRootOverrides[window.id] ?? conversation?.workingDirectory,
                environmentId: conversation?.environmentId,
                folderName: conversation?.workingDirectory.flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0).lastPathComponent },
                totalCost: conversation?.totalCost ?? 0,
                onSelectTab: { tab in windowManager.setWindowTab(window.id, tab: tab) }
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
                    isCompact: false,
                    isKeyboardVisible: isKeyboardVisible,
                    onInteraction: { dismissKeyboard() },
                    onSelectRecentConversation: { conv in
                        windowManager.linkToCurrentConversation(window.id, conversation: conv)
                    },
                    onSeeAllConversations: {
                        showConversationSearch = true
                    },
                    onNewConversation: {
                        let workingDir = activeWindowWorkingDirectory()
                        let newConv = conversationStore.newConversation(workingDirectory: workingDir, environmentId: activeWindowEnvironmentId())
                        windowManager.linkToCurrentConversation(window.id, conversation: newConv)
                    }
                )
                .id("\(window.id.uuidString)-\(refreshTrigger)")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(window.tab == .chat ? 1 : 0)
                .allowsHitTesting(window.tab == .chat)

                if window.tab == .files {
                    FileBrowserView(
                        connection: connection,
                        rootPath: window.fileBrowserRootPath ?? fileBrowserRootOverrides[window.id] ?? conversation?.workingDirectory,
                        environmentId: conversation?.environmentId
                    )
                }

                if window.tab == .gitChanges {
                    GitChangesView(
                        connection: connection,
                        rootPath: window.gitRepoRootPath ?? gitRepoRootOverrides[window.id] ?? conversation?.workingDirectory,
                        environmentId: conversation?.environmentId
                    )
                }

            }
        }
    }
}
