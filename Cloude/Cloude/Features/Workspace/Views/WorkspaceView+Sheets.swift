import SwiftUI

extension WorkspaceView {
    func editWindowSheet(_ window: Window) -> some View {
        let currentWindow = windowManager.windows.first(where: { $0.id == window.id }) ?? window
        return WindowEditSheet(
            window: currentWindow,
            conversationStore: conversationStore,
            windowManager: windowManager,
            environmentStore: environmentStore,
            onSelectConversation: { conversation in
                store.selectConversationForEditing(
                    conversation,
                    conversationStore: conversationStore,
                    windowManager: windowManager
                )
            },
            onDismiss: { store.editingWindow = nil },
            onRefresh: {
                await store.refreshEditingWindowConversation(
                    environmentStore: environmentStore,
                    conversationStore: conversationStore,
                    windowManager: windowManager
                )
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
