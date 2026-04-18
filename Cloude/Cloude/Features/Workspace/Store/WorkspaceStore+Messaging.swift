import Foundation
import UIKit
import CloudeShared

extension WorkspaceStore {
    func sendMessage(
        connection: ConnectionManager,
        conversationStore: ConversationStore,
        windowManager: WindowManager,
        environmentStore: EnvironmentStore,
        onShowSettings: (() -> Void)?,
        onShowWhiteboard: (() -> Void)?
    ) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let allImagesBase64 = WorkspaceImageEncoder.encodeFullImages(attachedImages)
        let thumbnails = WorkspaceImageEncoder.encodeThumbnails(attachedImages)
        let allFilesBase64 = encodeFiles(attachedFiles)

        guard !text.isEmpty || allImagesBase64 != nil || allFilesBase64 != nil else { return }
        MessageHistory.save(text, symbol: currentConversation(windowManager: windowManager, conversationStore: conversationStore)?.symbol)

        inputText = ""
        attachedImages = []
        attachedFiles = []
        if let activeId = windowManager.activeWindowId {
            drafts.removeValue(forKey: activeId)
        }

        let trimmedLower = text.lowercased().trimmingCharacters(in: .whitespaces)
        if trimmedLower == "/settings" {
            onShowSettings?()
            return
        }
        if trimmedLower == "/whiteboard" {
            onShowWhiteboard?()
            return
        }

        sendConversationMessage(
            text: text,
            imagesBase64: allImagesBase64,
            filesBase64: allFilesBase64,
            thumbnails: thumbnails,
            connection: connection,
            conversationStore: conversationStore,
            windowManager: windowManager,
            environmentStore: environmentStore
        )
    }

    func transcribeAudio(
        _ audioData: Data,
        connection: ConnectionManager,
        conversationStore: ConversationStore,
        windowManager: WindowManager,
        environmentStore: EnvironmentStore
    ) {
        let envId = currentConversation(windowManager: windowManager, conversationStore: conversationStore)?.environmentId ?? environmentStore.activeEnvironmentId
        connection.transcribe(audioBase64: audioData.base64EncodedString(), environmentId: envId)
    }

    func stopActiveConversation(connection: ConnectionManager, windowManager: WindowManager) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if let activeWindow = windowManager.activeWindow,
           let convId = activeWindow.conversationId {
            connection.abort(conversationId: convId)
        }
    }

    func sendConversationMessage(
        text: String,
        imagesBase64: [String]?,
        filesBase64: [AttachedFilePayload]?,
        thumbnails: [String]?,
        connection: ConnectionManager,
        conversationStore: ConversationStore,
        windowManager: WindowManager,
        environmentStore: EnvironmentStore
    ) {
        if windowManager.activeWindow == nil {
            windowManager.addWindow()
        }
        guard let activeWindow = windowManager.activeWindow else { return }

        var conversation = activeWindow.conversation(in: conversationStore)
        if conversation == nil {
            conversation = conversationStore.newConversation(
                workingDirectory: activeWindowWorkingDirectory(windowManager: windowManager, conversationStore: conversationStore),
                environmentId: activeWindowEnvironmentId(windowManager: windowManager, conversationStore: conversationStore, environmentStore: environmentStore)
            )
            windowManager.linkToCurrentConversation(activeWindow.id, conversation: conversation)
        }
        guard let conv = conversation else { return }

        if conv.environmentId == nil || connection.connection(for: conv.environmentId) == nil {
            conversationStore.setEnvironmentId(
                conv,
                environmentId: activeWindowEnvironmentId(
                    windowManager: windowManager,
                    conversationStore: conversationStore,
                    environmentStore: environmentStore
                )
            )
        }
        let updatedConv = conversationStore.conversation(withId: conv.id) ?? conv

        let isRunning = connection.output(for: updatedConv.id).isRunning
        if isRunning || !connection.isAuthenticated {
            AppLogger.connectionInfo("queue user message convId=\(updatedConv.id.uuidString) chars=\(text.count) running=\(isRunning) authenticated=\(connection.isAuthenticated)")
            let userMessage = ChatMessage(isUser: true, text: text, isQueued: true, imageBase64: thumbnails?.first, imageThumbnails: thumbnails)
            conversationStore.queueMessage(userMessage, to: updatedConv)
        } else {
            AppLogger.connectionInfo("send user message convId=\(updatedConv.id.uuidString) chars=\(text.count) images=\(imagesBase64?.count ?? 0) files=\(filesBase64?.count ?? 0)")
            let userMessage = ChatMessage(isUser: true, text: text, imageBase64: thumbnails?.first, imageThumbnails: thumbnails)
            conversationStore.addMessage(userMessage, to: updatedConv)

            let isFork = updatedConv.pendingFork
            let isNewSession = updatedConv.sessionId == nil && !isFork
            let effortValue = (currentEffort ?? updatedConv.defaultEffort)?.rawValue
            let modelValue = (currentModel ?? updatedConv.defaultModel)?.rawValue
            connection.sendChat(
                text,
                workingDirectory: updatedConv.workingDirectory,
                sessionId: updatedConv.sessionId,
                isNewSession: isNewSession,
                conversationId: updatedConv.id,
                imagesBase64: imagesBase64,
                filesBase64: filesBase64,
                conversationName: updatedConv.name,
                forkSession: isFork,
                effort: effortValue,
                model: modelValue,
                environmentId: updatedConv.environmentId
            )

            connection.output(for: updatedConv.id).liveMessageId = conversationStore.insertLiveMessage(into: updatedConv)

            if isNewSession {
                AppLogger.connectionInfo("request name suggestion convId=\(updatedConv.id.uuidString)")
                connection.requestNameSuggestion(text: text, context: [], conversationId: updatedConv.id)
            }

            if isFork {
                AppLogger.connectionInfo("clear pending fork convId=\(updatedConv.id.uuidString)")
                conversationStore.clearPendingFork(updatedConv)
            }
        }
    }

    func refreshConversation(for window: Window, connection: ConnectionManager, conversationStore: ConversationStore) {
        if let convId = window.conversationId,
           let conv = conversationStore.conversation(withId: convId),
           let sessionId = conv.sessionId,
           let workingDir = conv.workingDirectory,
           !workingDir.isEmpty {
            refreshingSessionIds.insert(sessionId)
            let messages = conversationStore.messages(for: conv)
            if let lastUserIndex = messages.lastIndex(where: { $0.isUser }) {
                conversationStore.truncateMessages(for: conv, from: lastUserIndex + 1)
            }
            connection.syncHistory(sessionId: sessionId, workingDirectory: workingDir, environmentId: conv.environmentId)
        }
    }

    private func encodeFiles(_ files: [AttachedFile]) -> [AttachedFilePayload]? {
        files.isEmpty ? nil : files.map { AttachedFilePayload(name: $0.name, data: $0.data.base64EncodedString()) }
    }
}
