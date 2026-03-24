//  MainChatView+Lifecycle.swift

import SwiftUI
import CloudeShared

extension MainChatView {
    func editWindowSheet(_ window: ChatWindow) -> some View {
        WindowEditSheet(
            window: window,
            conversationStore: conversationStore,
            windowManager: windowManager,
            connection: connection,
            environmentStore: environmentStore,
            onSelectConversation: { conv in
                if let oldConvId = editingWindow?.conversationId,
                   let oldConv = conversationStore.conversation(withId: oldConvId),
                   oldConv.isEmpty, oldConv.id != conv.id {
                    conversationStore.deleteConversation(oldConv)
                }
                if let window = editingWindow {
                    windowManager.linkToCurrentConversation(window.id, conversation: conv)
                }
                editingWindow = nil
            },
            onNewConversation: {
                if let oldConvId = editingWindow?.conversationId,
                   let oldConv = conversationStore.conversation(withId: oldConvId),
                   oldConv.isEmpty {
                    conversationStore.deleteConversation(oldConv)
                }
                let workingDir = activeWindowWorkingDirectory()
                let newConv = conversationStore.newConversation(workingDirectory: workingDir, environmentId: environmentStore.activeEnvironmentId)
                if let window = editingWindow {
                    windowManager.linkToCurrentConversation(window.id, conversation: newConv)
                }
                editingWindow = nil
            },
            onDismiss: { editingWindow = nil },
            onRefresh: {
                guard let convId = editingWindow?.conversationId,
                      let conv = conversationStore.conversation(withId: convId),
                      let sessionId = conv.sessionId,
                      let workingDir = conv.workingDirectory, !workingDir.isEmpty else { return }
                connection.syncHistory(sessionId: sessionId, workingDirectory: workingDir)
                try? await Task.sleep(for: .seconds(1))
            },
            onDuplicate: { newConv in
                if let window = editingWindow {
                    windowManager.linkToCurrentConversation(window.id, conversation: newConv)
                }
                editingWindow = nil
            }
        )
    }

    func handlePageChange(oldIndex: Int, newIndex: Int) {
        if oldIndex < windowManager.windows.count {
            let oldWindow = windowManager.windows[oldIndex]
            if let convId = oldWindow.conversationId,
               let conv = conversationStore.conversation(withId: convId),
               conv.isEmpty {
                conversationStore.deleteConversation(conv)
                windowManager.removeWindow(oldWindow.id)
            }
        }
        windowManager.navigateToWindow(at: newIndex)
    }

    func handleActiveWindowChange(oldId: UUID?, newId: UUID?) {
        if let oldId = oldId {
            drafts[oldId] = (inputText, attachedImages, currentEffort, currentModel)
            cleanupEmptyConversation(for: oldId)
        }
        if let newId = newId, let draft = drafts[newId] {
            inputText = draft.text
            attachedImages = draft.images
            currentEffort = draft.effort
            currentModel = draft.model
        } else {
            inputText = ""
            attachedImages = []
            currentEffort = currentConversation?.defaultEffort
            currentModel = currentConversation?.defaultModel
        }
    }

    func handleModelChange(_ oldModel: ModelSelection?, _ newModel: ModelSelection?) {
        if let conv = currentConversation, newModel != conv.defaultModel {
            conversationStore.setDefaultModel(conv, model: newModel)
        }
    }

    func handleEffortChange(_ oldEffort: EffortLevel?, _ newEffort: EffortLevel?) {
        if let conv = currentConversation, newEffort != conv.defaultEffort {
            conversationStore.setDefaultEffort(conv, effort: newEffort)
        }
    }

    @ViewBuilder
    func conversationSearchSheetContent() -> some View {
        ConversationSearchSheet(
            conversationStore: conversationStore,
            windowManager: windowManager,
            onSelect: { conv in
                showConversationSearch = false
                if let activeWindow = windowManager.activeWindow {
                    if let oldConvId = activeWindow.conversationId,
                       let oldConv = conversationStore.conversation(withId: oldConvId),
                       oldConv.isEmpty, oldConv.id != conv.id {
                        conversationStore.deleteConversation(oldConv)
                    }
                    windowManager.linkToCurrentConversation(activeWindow.id, conversation: conv)
                }
            }
        )
    }

    @ViewBuilder
    func usageStatsSheetContent() -> some View {
        if let stats = usageStats {
            UsageStatsSheet(stats: stats)
        } else {
            ProgressView("Loading usage stats...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.themeBackground)
        }
    }
}
