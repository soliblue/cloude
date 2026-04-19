import Foundation
import CloudeShared

extension WorkspaceStore {
    func initializeFirstWindow(conversationStore: ConversationStore, windowManager: WindowManager) {
        if let firstWindow = windowManager.windows.first,
           firstWindow.conversationId == nil,
           let conversation = conversationStore.listableConversations.first {
            windowManager.linkToCurrentConversation(firstWindow.id, conversation: conversation)
        }
    }

    func handleActiveWindowChange(
        oldId: UUID?,
        newId: UUID?,
        conversationStore: ConversationStore,
        windowManager: WindowManager,
        environmentStore: EnvironmentStore? = nil
    ) {
        if let oldId = oldId {
            drafts[oldId] = Draft(text: inputText, images: attachedImages, effort: currentEffort, model: currentModel)
            cleanupEmptyConversation(for: oldId, conversationStore: conversationStore, windowManager: windowManager)
        }
        if let newId = newId, let draft = drafts[newId] {
            inputText = draft.text
            attachedImages = draft.images
            currentEffort = draft.effort
            currentModel = draft.model
        } else {
            inputText = ""
            attachedImages = []
            currentEffort = currentConversation(windowManager: windowManager, conversationStore: conversationStore)?.defaultEffort
            currentModel = currentConversation(windowManager: windowManager, conversationStore: conversationStore)?.defaultModel
        }
        if let newId, let environmentStore {
            checkGitForActiveWindow(windowId: newId, conversationStore: conversationStore, windowManager: windowManager, environmentStore: environmentStore)
        }
    }

    func checkGitForActiveWindow(
        windowId: UUID,
        conversationStore: ConversationStore,
        windowManager: WindowManager,
        environmentStore: EnvironmentStore
    ) {
        let window = windowManager.windows.first(where: { $0.id == windowId })
        let conv = window?.conversation(in: conversationStore)
        if let dir = window?.gitRepoRootPath ?? conv?.workingDirectory,
           !dir.isEmpty {
            let envId = window?.runtimeEnvironmentId(conversationStore: conversationStore, environmentStore: environmentStore)
            environmentStore.connection(for: envId)?.git.requestStatus(dir)
        }
    }

    func handleModelChange(_ newModel: ModelSelection?, conversationStore: ConversationStore, windowManager: WindowManager) {
        if let conv = currentConversation(windowManager: windowManager, conversationStore: conversationStore),
           newModel != conv.defaultModel {
            conversationStore.setDefaultModel(conv, model: newModel)
        }
    }

    func handleEffortChange(_ newEffort: EffortLevel?, conversationStore: ConversationStore, windowManager: WindowManager) {
        if let conv = currentConversation(windowManager: windowManager, conversationStore: conversationStore),
           newEffort != conv.defaultEffort {
            conversationStore.setDefaultEffort(conv, effort: newEffort)
        }
    }

    func addWindowWithNewChat(
        conversationStore: ConversationStore,
        windowManager: WindowManager,
        environmentStore: EnvironmentStore
    ) {
        if !windowManager.canAddWindow {
            return
        }
        let runtime = activeRuntimeContext(
            environmentStore: environmentStore,
            windowManager: windowManager,
            conversationStore: conversationStore
        )
        let newWindowId = windowManager.addWindow()
        let newConv = conversationStore.newConversation(
            workingDirectory: runtime.workingDirectory,
            environmentId: runtime.environmentId
        )
        windowManager.linkToCurrentConversation(newWindowId, conversation: newConv)
    }

    func cleanupEmptyConversation(for windowId: UUID, conversationStore: ConversationStore, windowManager: WindowManager) {
        if let window = windowManager.windows.first(where: { $0.id == windowId }),
           let convId = window.conversationId,
           let conversation = conversationStore.conversation(withId: convId),
           conversation.isEmpty {
            conversationStore.deleteConversation(conversation)
            windowManager.removeWindow(windowId)
        }
    }
}
