import Foundation
import CloudeShared

extension WorkspaceStore {
    func dismissTransientUI() {
        editingWindow = nil
        showConversationSearch = false
    }

    func beginEditingWindow(_ windowId: UUID, windowManager: WindowManager) {
        editingWindow = windowManager.windows.first { $0.id == windowId }
    }

    func selectConversationForEditing(_ conversation: Conversation, conversationStore: ConversationStore, windowManager: WindowManager) {
        if let windowId = editingWindow?.id,
           let currentWindow = windowManager.windows.first(where: { $0.id == windowId }),
           let oldConvId = currentWindow.conversationId,
           let oldConv = conversationStore.conversation(withId: oldConvId),
           oldConv.isEmpty, oldConv.id != conversation.id {
            conversationStore.deleteConversation(oldConv)
        }
        if let windowId = editingWindow?.id {
            windowManager.linkToCurrentConversation(windowId, conversation: conversation)
        }
        editingWindow = nil
    }

    func refreshEditingWindowConversation(environmentStore: EnvironmentStore, conversationStore: ConversationStore, windowManager: WindowManager) async {
        if let windowId = editingWindow?.id,
           let currentWindow = windowManager.windows.first(where: { $0.id == windowId }),
           let convId = currentWindow.conversationId,
           let conversation = conversationStore.conversation(withId: convId),
           let sessionId = conversation.sessionId,
           let workingDirectory = conversation.workingDirectory, !workingDirectory.isEmpty {
            environmentStore.connection(for: conversation.environmentId)?.syncHistory(sessionId: sessionId, workingDirectory: workingDirectory)
            try? await Task.sleep(for: .seconds(1))
        }
    }

    func duplicateEditingConversation(_ conversation: Conversation, windowManager: WindowManager) {
        if let windowId = editingWindow?.id {
            windowManager.linkToCurrentConversation(windowId, conversation: conversation)
        }
        editingWindow = nil
    }

    func openConversationSearch() {
        showConversationSearch = true
    }

    func selectConversationFromSearch(_ conversation: Conversation, conversationStore: ConversationStore, windowManager: WindowManager) {
        showConversationSearch = false
        if let activeWindow = windowManager.activeWindow {
            if let oldConvId = activeWindow.conversationId,
               let oldConv = conversationStore.conversation(withId: oldConvId),
               oldConv.isEmpty, oldConv.id != conversation.id {
                conversationStore.deleteConversation(oldConv)
            }
            windowManager.linkToCurrentConversation(activeWindow.id, conversation: conversation)
        }
    }

}
