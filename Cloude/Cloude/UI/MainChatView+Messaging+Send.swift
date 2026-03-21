import SwiftUI
import CloudeShared

extension MainChatView {
    func sendHeartbeatMessage(text: String, imagesBase64: [String]?, filesBase64: [AttachedFilePayload]?, thumbnails: [String]?) {
        let convOutput = connection.output(for: Heartbeat.conversationId)
        let heartbeat = conversationStore.heartbeatConversation

        if convOutput.isRunning || !connection.isAuthenticated {
            let userMessage = ChatMessage(isUser: true, text: text, isQueued: true, imageBase64: thumbnails?.first, imageThumbnails: thumbnails)
            conversationStore.queueMessage(userMessage, to: heartbeat)
        } else {
            let userMessage = ChatMessage(isUser: true, text: text, imageBase64: thumbnails?.first, imageThumbnails: thumbnails)
            conversationStore.addMessage(userMessage, to: heartbeat)

            connection.sendChat(
                text,
                workingDirectory: nil,
                sessionId: Heartbeat.sessionId,
                isNewSession: false,
                conversationId: Heartbeat.conversationId,
                imagesBase64: imagesBase64,
                filesBase64: filesBase64,
                conversationName: "Heartbeat",
                conversationSymbol: "heart.fill",
                environmentId: heartbeatEnvId
            )
        }
    }

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
            let userMessage = ChatMessage(isUser: true, text: text, isQueued: true, imageBase64: thumbnails?.first, imageThumbnails: thumbnails)
            conversationStore.queueMessage(userMessage, to: conv)
        } else {
            let userMessage = ChatMessage(isUser: true, text: text, imageBase64: thumbnails?.first, imageThumbnails: thumbnails)
            conversationStore.addMessage(userMessage, to: conv)

            let isFork = conv.pendingFork
            let isNewSession = conv.sessionId == nil && !isFork
            let workingDir = conv.workingDirectory
            let effortValue = (currentEffort ?? conv.defaultEffort)?.rawValue
            let modelValue = (currentModel ?? conv.defaultModel)?.rawValue
            connection.sendChat(text, workingDirectory: workingDir, sessionId: conv.sessionId, isNewSession: isNewSession, conversationId: conv.id, imagesBase64: imagesBase64, filesBase64: filesBase64, conversationName: conv.name, conversationSymbol: conv.symbol, forkSession: isFork, effort: effortValue, model: modelValue, environmentId: conv.environmentId)

            if isNewSession {
                connection.requestNameSuggestion(text: text, context: [], conversationId: conv.id)
            }

            if isFork {
                conversationStore.clearPendingFork(conv)
            }
        }
    }
}
