import SwiftUI

extension MainChatView {
    @ViewBuilder
    func pagedWindowContent(for window: ChatWindow) -> some View {
        let conversation = window.conversation(in: conversationStore)

        VStack(spacing: 0) {
            windowHeader(for: window, conversation: conversation)

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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(window.type == .chat ? 1 : 0)
                .allowsHitTesting(window.type == .chat)

                if window.type == .files {
                    FileBrowserView(
                        connection: connection,
                        rootPath: conversation?.workingDirectory,
                        environmentId: conversation?.environmentId
                    )
                }

                if window.type == .gitChanges {
                    GitChangesView(
                        connection: connection,
                        rootPath: conversation?.workingDirectory,
                        environmentId: conversation?.environmentId
                    )
                }

            }
        }
    }
}
