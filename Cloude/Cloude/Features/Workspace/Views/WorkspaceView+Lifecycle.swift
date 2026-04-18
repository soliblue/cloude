import SwiftUI
import CloudeShared

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
            onNewConversation: {
                store.createConversationForEditing(
                    conversationStore: conversationStore,
                    windowManager: windowManager,
                    environmentStore: environmentStore
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
