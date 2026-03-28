import SwiftUI
import CloudeShared

extension MainChatView {
    func sendConversationMessage(text: String, imagesBase64: [String]?, filesBase64: [AttachedFilePayload]?, thumbnails: [String]?) {
        if windowManager.activeWindow == nil {
            windowManager.addWindow()
        }
        guard let activeWindow = windowManager.activeWindow else { return }

        var conversation = activeWindow.conversation(in: conversationStore)
        if conversation == nil {
            let workingDir = activeWindowWorkingDirectory()
            conversation = conversationStore.newConversation(workingDirectory: workingDir, environmentId: activeWindowEnvironmentId())
            windowManager.linkToCurrentConversation(activeWindow.id, conversation: conversation)
        }
        guard let conv = conversation else { return }

        if conv.environmentId == nil {
            conversationStore.setEnvironmentId(conv, environmentId: activeWindowEnvironmentId())
        }

        let isRunning = connection.output(for: conv.id).isRunning

        if isRunning || !connection.isAuthenticated {
            AppLogger.connectionInfo("queue user message convId=\(conv.id.uuidString) chars=\(text.count) running=\(isRunning) authenticated=\(connection.isAuthenticated)")
            let userMessage = ChatMessage(isUser: true, text: text, isQueued: true, imageBase64: thumbnails?.first, imageThumbnails: thumbnails)
            conversationStore.queueMessage(userMessage, to: conv)
        } else {
            AppLogger.connectionInfo("send user message convId=\(conv.id.uuidString) chars=\(text.count) images=\(imagesBase64?.count ?? 0) files=\(filesBase64?.count ?? 0)")
            let userMessage = ChatMessage(isUser: true, text: text, imageBase64: thumbnails?.first, imageThumbnails: thumbnails)
            conversationStore.addMessage(userMessage, to: conv)

            let isFork = conv.pendingFork
            let isNewSession = conv.sessionId == nil && !isFork
            let workingDir = conv.workingDirectory
            let effortValue = (currentEffort ?? conv.defaultEffort)?.rawValue
            let modelValue = (currentModel ?? conv.defaultModel)?.rawValue
            connection.sendChat(text, workingDirectory: workingDir, sessionId: conv.sessionId, isNewSession: isNewSession, conversationId: conv.id, imagesBase64: imagesBase64, filesBase64: filesBase64, conversationName: conv.name, conversationSymbol: conv.symbol, forkSession: isFork, effort: effortValue, model: modelValue, environmentId: conv.environmentId)

            if isNewSession {
                AppLogger.connectionInfo("request name suggestion convId=\(conv.id.uuidString)")
                connection.requestNameSuggestion(text: text, context: [], conversationId: conv.id)
            }

            if isFork {
                AppLogger.connectionInfo("clear pending fork convId=\(conv.id.uuidString)")
                conversationStore.clearPendingFork(conv)
            }
        }
    }
}
