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
                onSelectConversationForEditing(currentWindow, conversation)
                store.windowBeingEdited = nil
            },
            onDismiss: { store.windowBeingEdited = nil },
            onRefresh: {
                await onRefreshEditingWindowConversation(currentWindow)
            },
            onDuplicate: { newConversation in
                onDuplicateEditingConversation(currentWindow, newConversation)
                store.windowBeingEdited = nil
            }
        )
    }
}
