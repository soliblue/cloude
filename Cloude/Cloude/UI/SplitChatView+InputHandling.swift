//
//  SplitChatView+InputHandling.swift
//  Cloude
//

import SwiftUI
import UIKit

extension SplitChatView {
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

        guard let activeWindow = windowManager.activeWindow else { return }

        var project = activeWindow.projectId.flatMap { pid in projectStore.projects.first { $0.id == pid } }
        if project == nil {
            project = projectStore.createProject(name: "Default Project")
        }
        guard let proj = project else { return }

        var conversation = proj.conversations.first { $0.id == activeWindow.conversationId }
        if conversation == nil {
            conversation = projectStore.newConversation(in: proj)
            windowManager.linkToCurrentConversation(activeWindow.id, project: proj, conversation: conversation)
        }
        guard let conv = conversation else { return }

        let isRunning = connection.output(for: conv.id).isRunning

        if isRunning {
            let userMessage = ChatMessage(isUser: true, text: text, isQueued: true, imageBase64: thumbnailBase64)
            projectStore.queueMessage(userMessage, to: conv, in: proj)
        } else {
            let userMessage = ChatMessage(isUser: true, text: text, imageBase64: thumbnailBase64)
            projectStore.addMessage(userMessage, to: conv, in: proj)

            let isNewSession = conv.sessionId == nil
            let workingDir = proj.rootDirectory.isEmpty ? nil : proj.rootDirectory
            connection.sendChat(text, workingDirectory: workingDir, sessionId: conv.sessionId, isNewSession: isNewSession, conversationId: conv.id, imageBase64: fullImageBase64)
        }

        inputText = ""
        selectedImageData = nil
        if let activeId = windowManager.activeWindowId {
            drafts.removeValue(forKey: activeId)
        }
    }

    func transcribeAudio(_ audioData: Data) {
        print("[iOS] Sending audio for transcription: \(audioData.count) bytes")
        connection.transcribe(audioBase64: audioData.base64EncodedString())
    }

    func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
