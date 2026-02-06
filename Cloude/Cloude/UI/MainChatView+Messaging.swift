import SwiftUI
import UIKit
import Combine
import CloudeShared

extension MainChatView {
    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullImageBase64 = selectedImageData?.base64EncodedString()

        var thumbnailBase64: String? = nil
        if let imageData = selectedImageData,
           let image = UIImage(data: imageData),
           let thumbnail = image.preparingThumbnail(of: CGSize(width: 200, height: 200)),
           let thumbData = thumbnail.jpegData(compressionQuality: 0.7) {
            thumbnailBase64 = thumbData.base64EncodedString()
        }

        guard !text.isEmpty || fullImageBase64 != nil else { return }

        if isHeartbeatActive {
            sendHeartbeatMessage(text: text, imageBase64: fullImageBase64, thumbnailBase64: thumbnailBase64)
        } else {
            sendConversationMessage(text: text, imageBase64: fullImageBase64, thumbnailBase64: thumbnailBase64)
        }

        inputText = ""
        selectedImageData = nil
        if let activeId = windowManager.activeWindowId {
            drafts.removeValue(forKey: activeId)
        }
    }

    func sendHeartbeatMessage(text: String, imageBase64: String?, thumbnailBase64: String?) {
        let convOutput = connection.output(for: Heartbeat.conversationId)
        let heartbeat = conversationStore.heartbeatConversation

        if convOutput.isRunning {
            let userMessage = ChatMessage(isUser: true, text: text, isQueued: true, imageBase64: thumbnailBase64)
            conversationStore.queueMessage(userMessage, to: heartbeat)
        } else {
            let userMessage = ChatMessage(isUser: true, text: text, imageBase64: thumbnailBase64)
            conversationStore.addMessage(userMessage, to: heartbeat)

            connection.sendChat(
                text,
                workingDirectory: nil,
                sessionId: Heartbeat.sessionId,
                isNewSession: false,
                conversationId: Heartbeat.conversationId,
                imageBase64: imageBase64,
                conversationName: "Heartbeat",
                conversationSymbol: "heart.fill"
            )
        }
    }

    func sendConversationMessage(text: String, imageBase64: String?, thumbnailBase64: String?) {
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

        let isRunning = connection.output(for: conv.id).isRunning

        if isRunning {
            let userMessage = ChatMessage(isUser: true, text: text, isQueued: true, imageBase64: thumbnailBase64)
            conversationStore.queueMessage(userMessage, to: conv)
        } else {
            let userMessage = ChatMessage(isUser: true, text: text, imageBase64: thumbnailBase64)
            conversationStore.addMessage(userMessage, to: conv)

            let isFork = conv.pendingFork
            let isNewSession = conv.sessionId == nil && !isFork
            let workingDir = conv.workingDirectory
            let effortValue = (currentEffort ?? conv.defaultEffort)?.rawValue
            connection.sendChat(text, workingDirectory: workingDir, sessionId: conv.sessionId, isNewSession: isNewSession, conversationId: conv.id, imageBase64: imageBase64, conversationName: conv.name, conversationSymbol: conv.symbol, forkSession: isFork, effort: effortValue)

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
