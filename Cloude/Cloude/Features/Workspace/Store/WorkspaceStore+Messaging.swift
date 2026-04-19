import Foundation
import UIKit
import CloudeShared

extension WorkspaceStore {
    func sendMessage(
        conversationStore: ConversationStore,
        windowManager: WindowManager,
        environmentStore: EnvironmentStore,
        onShowSettings: (() -> Void)?
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

        sendConversationMessage(
            text: text,
            imagesBase64: allImagesBase64,
            filesBase64: allFilesBase64,
            thumbnails: thumbnails,
            conversationStore: conversationStore,
            windowManager: windowManager,
            environmentStore: environmentStore
        )
    }

    func transcribeAudio(
        _ audioData: Data,
        conversationStore: ConversationStore,
        windowManager: WindowManager,
        environmentStore: EnvironmentStore
    ) {
        let runtime = activeRuntimeContext(
            environmentStore: environmentStore,
            windowManager: windowManager,
            conversationStore: conversationStore
        )
        runtime.connection?.transcribe(audioBase64: audioData.base64EncodedString())
    }

    func stopActiveConversation(environmentStore: EnvironmentStore, windowManager: WindowManager, conversationStore: ConversationStore) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if let activeWindow = windowManager.activeWindow,
           let convId = activeWindow.conversationId,
           let conv = conversationStore.conversation(withId: convId) {
            environmentStore.connection(for: conv.environmentId)?.abort(conversationId: convId)
        }
    }

    func sendConversationMessage(
        text: String,
        imagesBase64: [String]?,
        filesBase64: [AttachedFilePayload]?,
        thumbnails: [String]?,
        conversationStore: ConversationStore,
        windowManager: WindowManager,
        environmentStore: EnvironmentStore
    ) {
        guard let activeWindow = windowManager.ensureActiveWindow() else { return }
        let runtime = activeRuntimeContext(
            environmentStore: environmentStore,
            windowManager: windowManager,
            conversationStore: conversationStore
        )

        var conversation = activeWindow.conversation(in: conversationStore)
        if conversation == nil {
            conversation = conversationStore.newConversation(
                workingDirectory: runtime.workingDirectory,
                environmentId: runtime.environmentId
            )
            windowManager.linkToCurrentConversation(activeWindow.id, conversation: conversation)
        }
        guard let conv = conversation else { return }

        if conv.environmentId == nil || environmentStore.connection(for: conv.environmentId) == nil {
            conversationStore.setEnvironmentId(
                conv,
                environmentId: runtime.environmentId
            )
        }
        let updatedConv = conversationStore.conversation(withId: conv.id) ?? conv

        let userMessage = ChatMessage(kind: .user(), text: text, imageBase64: thumbnails?.first, imageThumbnails: thumbnails)
        conversationStore.dispatchUserTurn(
            userMessage,
            to: updatedConv,
            environmentStore: environmentStore,
            imagesBase64: imagesBase64,
            filesBase64: filesBase64,
            effort: (currentEffort ?? updatedConv.defaultEffort)?.rawValue,
            model: (currentModel ?? updatedConv.defaultModel)?.rawValue,
            source: "user message"
        )
    }

    func refreshConversation(for window: Window, environmentStore: EnvironmentStore, conversationStore: ConversationStore) {
        if let convId = window.conversationId,
           let conv = conversationStore.conversation(withId: convId),
           let sessionId = conv.sessionId,
           let workingDir = conv.workingDirectory,
           !workingDir.isEmpty {
            let messages = conversationStore.messages(for: conv)
            if let lastUserIndex = messages.lastIndex(where: { $0.isUser }) {
                conversationStore.truncateMessages(for: conv, from: lastUserIndex + 1)
            }
            environmentStore.connection(for: conv.environmentId)?.syncHistory(sessionId: sessionId, workingDirectory: workingDir)
        }
    }

    private func encodeFiles(_ files: [AttachedFile]) -> [AttachedFilePayload]? {
        files.isEmpty ? nil : files.map { AttachedFilePayload(name: $0.name, data: $0.data.base64EncodedString()) }
    }
}
