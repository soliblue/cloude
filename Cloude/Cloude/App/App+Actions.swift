import SwiftUI
import CloudeShared

extension App {
    func activeConversation() -> Conversation? {
        windowManager.activeWindow?.conversation(in: conversationStore)
    }

    func selectConversation(id: UUID) {
        guard let conversation = conversationStore.conversation(withId: id) else {
            AppLogger.bootstrapInfo("select conversation failed convId=\(id.uuidString)")
            return
        }
        if windowManager.activeWindow == nil {
            windowManager.addWindow()
        }
        guard let activeWindow = windowManager.activeWindow else { return }
        windowManager.linkToCurrentConversation(activeWindow.id, conversation: conversation)
        AppLogger.bootstrapInfo("selected conversation convId=\(id.uuidString) windowId=\(activeWindow.id.uuidString)")
    }

    func createNewConversation(path: String? = nil) {
        if windowManager.activeWindow == nil {
            windowManager.addWindow()
        }
        guard let activeWindow = windowManager.activeWindow else { return }

        let workingDirectory = path?.nilIfEmpty
        let conversation = conversationStore.newConversation(
            workingDirectory: workingDirectory,
            environmentId: environmentStore.activeEnvironmentId
        )
        windowManager.linkToCurrentConversation(activeWindow.id, conversation: conversation)
        AppLogger.bootstrapInfo(
            "created new conversation convId=\(conversation.id.uuidString) windowId=\(activeWindow.id.uuidString) path=\(workingDirectory ?? "-")"
        )
    }

    func duplicateActiveConversation() {
        guard let conversation = activeConversation(),
              let duplicate = conversationStore.duplicateConversation(conversation) else {
            AppLogger.bootstrapInfo("duplicate conversation ignored")
            return
        }
        if let activeWindow = windowManager.activeWindow {
            windowManager.linkToCurrentConversation(activeWindow.id, conversation: duplicate)
        }
        AppLogger.bootstrapInfo("duplicated conversation source=\(conversation.id.uuidString) duplicate=\(duplicate.id.uuidString)")
    }

    func refreshActiveConversation() {
        guard let conversation = activeConversation(),
              let sessionId = conversation.sessionId else {
            AppLogger.bootstrapInfo("refresh conversation ignored")
            return
        }
        let workingDirectory = conversation.workingDirectory
            ?? connection.connection(for: conversation.environmentId ?? environmentStore.activeEnvironmentId)?.defaultWorkingDirectory
        guard let workingDirectory, !workingDirectory.isEmpty else {
            AppLogger.bootstrapInfo("refresh conversation ignored missing working directory convId=\(conversation.id.uuidString)")
            return
        }
        AppLogger.beginInterval("conversation.refresh", key: conversation.id.uuidString, details: "sessionId=\(sessionId)")
        connection.syncHistory(sessionId: sessionId, workingDirectory: workingDirectory, environmentId: conversation.environmentId)
        AppLogger.bootstrapInfo("refresh conversation convId=\(conversation.id.uuidString)")
    }

    func stopActiveRun() {
        guard let conversation = activeConversation() else {
            AppLogger.bootstrapInfo("stop run ignored no active conversation")
            return
        }
        connection.abort(conversationId: conversation.id)
        AppLogger.bootstrapInfo("stop run convId=\(conversation.id.uuidString)")
    }

    func setActiveConversationModel(_ value: String?) {
        guard let conversation = activeConversation() else { return }
        let model = value.flatMap(ModelSelection.init(rawValue:))
        conversationStore.setDefaultModel(conversation, model: model)
        AppLogger.bootstrapInfo("set conversation model convId=\(conversation.id.uuidString) model=\(model?.rawValue ?? "nil")")
    }

    func setActiveConversationEffort(_ value: String?) {
        guard let conversation = activeConversation() else { return }
        let effort = value.flatMap(EffortLevel.init(rawValue:))
        conversationStore.setDefaultEffort(conversation, effort: effort)
        AppLogger.bootstrapInfo("set conversation effort convId=\(conversation.id.uuidString) effort=\(effort?.rawValue ?? "nil")")
    }

    func sendDebugMessage(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            AppLogger.bootstrapInfo("debug send ignored empty text")
            return
        }

        if windowManager.activeWindow == nil {
            windowManager.addWindow()
        }
        guard let activeWindow = windowManager.activeWindow else {
            AppLogger.bootstrapInfo("debug send failed missing active window")
            return
        }

        var conversation = activeWindow.conversation(in: conversationStore)
        if conversation == nil {
            conversation = conversationStore.newConversation(environmentId: environmentStore.activeEnvironmentId)
            windowManager.linkToCurrentConversation(activeWindow.id, conversation: conversation)
            AppLogger.bootstrapInfo("debug send created conversation windowId=\(activeWindow.id.uuidString)")
        }
        guard let conv = conversation else {
            AppLogger.bootstrapInfo("debug send failed missing conversation")
            return
        }

        if conv.environmentId == nil {
            conversationStore.setEnvironmentId(conv, environmentId: environmentStore.activeEnvironmentId)
        }
        let updatedConv = conversationStore.conversation(withId: conv.id) ?? conv
        let targetEnvironmentId = updatedConv.environmentId ?? environmentStore.activeEnvironmentId
        let isRunning = connection.output(for: updatedConv.id).isRunning
        let isAuthenticated = connection.connection(for: targetEnvironmentId)?.isAuthenticated ?? connection.isAuthenticated

        if isRunning || !isAuthenticated {
            AppLogger.connectionInfo("debug send queue convId=\(updatedConv.id.uuidString) chars=\(trimmedText.count) running=\(isRunning) authenticated=\(isAuthenticated)")
            let queuedMessage = ChatMessage(isUser: true, text: trimmedText, isQueued: true)
            conversationStore.queueMessage(queuedMessage, to: updatedConv)
            return
        }

        AppLogger.connectionInfo("debug send send convId=\(updatedConv.id.uuidString) chars=\(trimmedText.count)")
        let userMessage = ChatMessage(isUser: true, text: trimmedText)
        conversationStore.addMessage(userMessage, to: updatedConv)

        let isFork = updatedConv.pendingFork
        let isNewSession = updatedConv.sessionId == nil && !isFork
        let effortValue = updatedConv.defaultEffort?.rawValue
        let modelValue = updatedConv.defaultModel?.rawValue
        connection.sendChat(
            trimmedText,
            workingDirectory: updatedConv.workingDirectory,
            sessionId: updatedConv.sessionId,
            isNewSession: isNewSession,
            conversationId: updatedConv.id,
            conversationName: updatedConv.name,
            conversationSymbol: updatedConv.symbol,
            forkSession: isFork,
            effort: effortValue,
            model: modelValue,
            environmentId: updatedConv.environmentId
        )

        if isNewSession {
            AppLogger.connectionInfo("debug send request name suggestion convId=\(updatedConv.id.uuidString)")
            connection.requestNameSuggestion(text: trimmedText, context: [], conversationId: updatedConv.id)
        }

        if isFork {
            AppLogger.connectionInfo("debug send clear pending fork convId=\(updatedConv.id.uuidString)")
            conversationStore.clearPendingFork(updatedConv)
        }
    }
}
