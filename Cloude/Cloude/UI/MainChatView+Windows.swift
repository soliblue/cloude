import SwiftUI

extension MainChatView {
    @ViewBuilder
    func pagedWindowContent(for window: ChatWindow) -> some View {
        let conversation = window.conversation(in: conversationStore)

        VStack(spacing: 0) {
            WindowTabBar(
                activeType: window.type,
                envConnected: (conversation?.environmentId).flatMap({ connection.connection(for: $0)?.isConnected }) ?? false,
                onSelectType: { type in windowManager.setWindowType(window.id, type: type) }
            )

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
                .opacity(window.type == .chat ? 1 : 0)
                .allowsHitTesting(window.type == .chat)

                if window.type == .files {
                    FileBrowserView(
                        connection: connection,
                        rootPath: window.fileBrowserRootPath ?? fileBrowserRootOverrides[window.id] ?? conversation?.workingDirectory,
                        environmentId: conversation?.environmentId
                    )
                }

                if window.type == .gitChanges {
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
