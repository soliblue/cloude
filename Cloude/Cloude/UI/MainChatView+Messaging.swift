import SwiftUI
import UIKit
import CloudeShared

extension MainChatView {
    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let allImagesBase64 = ImageEncoder.encodeFullImages(attachedImages)
        let thumbnails = ImageEncoder.encodeThumbnails(attachedImages)
        let allFilesBase64 = encodeFiles(attachedFiles)

        guard !text.isEmpty || allImagesBase64 != nil || allFilesBase64 != nil else { return }

        if isHeartbeatActive {
            sendHeartbeatMessage(text: text, imagesBase64: allImagesBase64, filesBase64: allFilesBase64, thumbnails: thumbnails)
        } else {
            sendConversationMessage(text: text, imagesBase64: allImagesBase64, filesBase64: allFilesBase64, thumbnails: thumbnails)
        }

        inputText = ""
        attachedImages = []
        attachedFiles = []
        if let activeId = windowManager.activeWindowId {
            drafts.removeValue(forKey: activeId)
        }
    }

    private func encodeFiles(_ files: [AttachedFile]) -> [AttachedFilePayload]? {
        guard !files.isEmpty else { return nil }
        return files.map { AttachedFilePayload(name: $0.name, data: $0.data.base64EncodedString()) }
    }

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
                conversationSymbol: "heart.fill"
            )
        }
    }

    func sendConversationMessage(text: String, imagesBase64: [String]?, filesBase64: [AttachedFilePayload]?, thumbnails: [String]?) {
        if windowManager.activeWindow == nil {
            windowManager.addWindow()
        }
        guard let activeWindow = windowManager.activeWindow else { return }

        var conversation = activeWindow.conversationId.flatMap { conversationStore.conversation(withId: $0) }
        if conversation == nil {
            let workingDir = activeWindowWorkingDirectory()
            conversation = conversationStore.newConversation(workingDirectory: workingDir)
            windowManager.linkToCurrentConversation(activeWindow.id, conversation: conversation)
        }
        guard let conv = conversation else { return }

        if let limit = conv.costLimitUsd, limit > 0, conv.totalCost >= limit {
            return
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
            connection.sendChat(text, workingDirectory: workingDir, sessionId: conv.sessionId, isNewSession: isNewSession, conversationId: conv.id, imagesBase64: imagesBase64, filesBase64: filesBase64, conversationName: conv.name, conversationSymbol: conv.symbol, forkSession: isFork, effort: effortValue, model: modelValue)

            if isNewSession {
                connection.requestNameSuggestion(text: text, context: [], conversationId: conv.id)
            }

            if isFork {
                conversationStore.clearPendingFork(conv)
            }
        }
    }

    func transcribeAudio(_ audioData: Data) {
        connection.transcribe(audioBase64: audioData.base64EncodedString())
    }

    func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    var activeConversationIsRunning: Bool {
        if isHeartbeatActive {
            return connection.output(for: Heartbeat.conversationId).isRunning
        }
        guard let activeWindow = windowManager.activeWindow,
              let convId = activeWindow.conversationId else { return false }
        return connection.output(for: convId).isRunning
    }

    func stopActiveConversation() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        if isHeartbeatActive {
            connection.abort(conversationId: Heartbeat.conversationId)
        } else if let activeWindow = windowManager.activeWindow,
                  let convId = activeWindow.conversationId {
            connection.abort(conversationId: convId)
        }
    }
}
