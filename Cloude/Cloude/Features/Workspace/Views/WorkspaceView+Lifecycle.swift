import SwiftUI

extension WorkspaceView {
    func editWindowSheet(_ window: Window) -> some View {
        WindowEditSheet(
            window: window,
            conversationStore: conversationStore,
            windowManager: windowManager,
            connection: connection,
            environmentStore: environmentStore,
            onSelectConversation: { conversation in
                store.selectConversationForEditing(
                    conversation,
                    conversationStore: conversationStore,
                    windowManager: windowManager
                )
            },
            onDismiss: { store.dismissEditingWindow() },
            onRefresh: {
                await store.refreshEditingWindowConversation(connection: connection, conversationStore: conversationStore)
            },
            onDuplicate: { newConv in
                store.duplicateEditingConversation(newConv, windowManager: windowManager)
            }
        )
    }

    @ViewBuilder
    func conversationSearchSheetContent() -> some View {
        ConversationSearchSheet(
            conversationStore: conversationStore,
            onSelect: { conversation in
                store.selectConversationFromSearch(
                    conversation,
                    conversationStore: conversationStore,
                    windowManager: windowManager
                )
            }
        )
    }
}
