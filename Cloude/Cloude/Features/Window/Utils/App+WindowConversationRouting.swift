import Foundation

extension App {
    func handleSwitchConversation(conversationId: UUID) {
        if let conversation = conversationStore.findConversation(withId: conversationId) {
            let targetId = windowManager.activeWindowId ?? windowManager.windows.first?.id
            if let targetId {
                windowManager.selectConversation(
                    conversation,
                    in: targetId,
                    conversationStore: conversationStore
                )
            }
        }
    }

    func selectConversationForEditing(_ conversation: Conversation, in window: Window) {
        windowManager.selectConversation(
            conversation,
            in: window.id,
            conversationStore: conversationStore
        )
    }

    func duplicateEditingConversation(_ conversation: Conversation, in window: Window) {
        windowManager.linkToCurrentConversation(window.id, conversation: conversation)
    }

    func selectConversationFromSearch(_ conversation: Conversation) {
        if let activeWindow = windowManager.activeWindow {
            windowManager.selectConversation(
                conversation,
                in: activeWindow.id,
                conversationStore: conversationStore
            )
        }
    }
}
