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
        if let oldConvId = editingWindow?.conversationId,
           let oldConv = conversationStore.conversation(withId: oldConvId),
           oldConv.isEmpty, oldConv.id != conversation.id {
            conversationStore.deleteConversation(oldConv)
        }
        if let window = editingWindow {
            windowManager.linkToCurrentConversation(window.id, conversation: conversation)
        }
        editingWindow = nil
    }

    func createConversationForEditing(conversationStore: ConversationStore, windowManager: WindowManager, environmentStore: EnvironmentStore) {
        if let oldConvId = editingWindow?.conversationId,
           let oldConv = conversationStore.conversation(withId: oldConvId),
           oldConv.isEmpty {
            conversationStore.deleteConversation(oldConv)
        }
        let workingDirectory = activeWindowWorkingDirectory(windowManager: windowManager, conversationStore: conversationStore)
        let conversation = conversationStore.newConversation(workingDirectory: workingDirectory, environmentId: environmentStore.activeEnvironmentId)
        if let window = editingWindow {
            windowManager.linkToCurrentConversation(window.id, conversation: conversation)
        }
        editingWindow = nil
    }

    func refreshEditingWindowConversation(environmentStore: EnvironmentStore, conversationStore: ConversationStore) async {
        if let convId = editingWindow?.conversationId,
           let conversation = conversationStore.conversation(withId: convId),
           let sessionId = conversation.sessionId,
           let workingDirectory = conversation.workingDirectory, !workingDirectory.isEmpty {
            environmentStore.connection(for: conversation.environmentId)?.syncHistory(sessionId: sessionId, workingDirectory: workingDirectory)
            try? await Task.sleep(for: .seconds(1))
        }
    }

    func duplicateEditingConversation(_ conversation: Conversation, windowManager: WindowManager) {
        if let window = editingWindow {
            windowManager.linkToCurrentConversation(window.id, conversation: conversation)
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
