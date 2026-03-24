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
        MessageHistory.save(text)

        dismissKeyboard()
        DispatchQueue.main.async {
            inputText = ""
            attachedImages = []
            attachedFiles = []
            if let activeId = windowManager.activeWindowId {
                drafts.removeValue(forKey: activeId)
            }
        }

        let trimmedLower = text.lowercased().trimmingCharacters(in: .whitespaces)

        if trimmedLower == "/usage" {
            awaitingUsageStats = true
            connection.getUsageStats(environmentId: currentConversation?.environmentId ?? environmentStore.activeEnvironmentId)
            return
        }

        if trimmedLower == "/plans" {
            onShowPlans?()
            return
        }

        if trimmedLower == "/memories" {
            onShowMemories?()
            return
        }

        if trimmedLower == "/settings" {
            onShowSettings?()
            return
        }

        if trimmedLower == "/whiteboard" {
            onShowWhiteboard?()
            return
        }

        sendConversationMessage(text: text, imagesBase64: allImagesBase64, filesBase64: allFilesBase64, thumbnails: thumbnails)
    }

    private func encodeFiles(_ files: [AttachedFile]) -> [AttachedFilePayload]? {
        guard !files.isEmpty else { return nil }
        return files.map { AttachedFilePayload(name: $0.name, data: $0.data.base64EncodedString()) }
    }

    func transcribeAudio(_ audioData: Data) {
        let envId = currentConversation?.environmentId ?? environmentStore.activeEnvironmentId
        connection.transcribe(audioBase64: audioData.base64EncodedString(), environmentId: envId)
    }

    func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    var activeConversationIsRunning: Bool {
        if let activeWindow = windowManager.activeWindow,
           let convId = activeWindow.conversationId {
            return connection.output(for: convId).isRunning
        }
        return false
    }

    func stopActiveConversation() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        if let activeWindow = windowManager.activeWindow,
           let convId = activeWindow.conversationId {
            connection.abort(conversationId: convId)
        }
    }
}
