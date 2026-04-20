import Foundation
import CloudeShared

extension WindowManager {
    func initializeFirstWindow(conversationStore: ConversationStore, environmentStore: EnvironmentStore) {
        if let firstWindow = windows.first,
           firstWindow.conversationId == nil {
            if let conversation = conversationStore.conversations.first {
                linkToCurrentConversation(firstWindow.id, conversation: conversation)
            } else {
                let runtime = firstWindow.runtimeContext(
                    conversationStore: conversationStore,
                    environmentStore: environmentStore
                )
                let conversation = conversationStore.newConversation(
                    workingDirectory: runtime.workingDirectory,
                    environmentId: runtime.environmentId
                )
                linkToCurrentConversation(firstWindow.id, conversation: conversation)
            }
        }
    }

    func handleActiveWindowChange(
        oldId: UUID?,
        newId: UUID?,
        conversationStore: ConversationStore,
        environmentStore: EnvironmentStore
    ) {
        if let oldId = oldId {
            cleanupEmptyConversation(for: oldId, conversationStore: conversationStore)
        }
        if let newId,
           let window = windows.first(where: { $0.id == newId }),
           window.conversationId == nil {
            let runtime = window.runtimeContext(
                conversationStore: conversationStore,
                environmentStore: environmentStore
            )
            let conversation = conversationStore.newConversation(
                workingDirectory: runtime.workingDirectory,
                environmentId: runtime.environmentId
            )
            linkToCurrentConversation(newId, conversation: conversation)
        }
        if let newId {
            checkGitForActiveWindow(windowId: newId, conversationStore: conversationStore, environmentStore: environmentStore)
        }
    }

    func checkGitForActiveWindow(
        windowId: UUID,
        conversationStore: ConversationStore,
        environmentStore: EnvironmentStore
    ) {
        let window = windows.first(where: { $0.id == windowId })
        let conversation = window?.conversation(in: conversationStore)
        if let workingDirectory = conversation?.workingDirectory,
           !workingDirectory.isEmpty {
            let environmentId = window?.runtimeEnvironmentId(
                conversationStore: conversationStore,
                environmentStore: environmentStore
            )
            environmentStore.connectionStore.connection(for: environmentId)?.git.requestStatus(workingDirectory)
        }
    }

    func addWindowWithNewChat(conversationStore: ConversationStore, environmentStore: EnvironmentStore) {
        if !canAddWindow {
            return
        }
        let environmentId: UUID?
        let workingDirectory: String?
        if let activeWindow = activeWindow {
            let runtime = activeWindow.runtimeContext(
                conversationStore: conversationStore,
                environmentStore: environmentStore
            )
            environmentId = runtime.environmentId
            workingDirectory = runtime.workingDirectory
        } else {
            environmentId = environmentStore.activeEnvironmentId
            workingDirectory = environmentStore.connectionStore.connection(for: environmentId)?.defaultWorkingDirectory?.nilIfEmpty
        }
        let newWindowId = addWindow()
        let newConversation = conversationStore.newConversation(
            workingDirectory: workingDirectory,
            environmentId: environmentId
        )
        linkToCurrentConversation(newWindowId, conversation: newConversation)
    }

    func cleanupEmptyConversation(for windowId: UUID, conversationStore: ConversationStore) {
        if let window = windows.first(where: { $0.id == windowId }),
           let conversationId = window.conversationId,
           let conversation = conversationStore.conversation(withId: conversationId),
           conversation.isEmpty {
            conversationStore.deleteConversation(conversation)
            removeWindow(windowId)
        }
    }
}
