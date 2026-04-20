import Foundation
import CloudeShared

extension WindowManager {
    func selectConversation(_ conversation: Conversation, in windowId: UUID, conversationStore: ConversationStore) {
        if let currentWindow = windows.first(where: { $0.id == windowId }),
           let oldConversationId = currentWindow.conversationId,
           let oldConversation = conversationStore.conversation(withId: oldConversationId),
           oldConversation.isEmpty,
           oldConversation.id != conversation.id {
            conversationStore.deleteConversation(oldConversation)
        }
        linkToCurrentConversation(windowId, conversation: conversation)
    }
}
