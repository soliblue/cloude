import Foundation
import UIKit
import CloudeShared

extension WorkspaceStore {
    func sendMessage(
        connection: ConnectionManager,
        conversationStore: ConversationStore,
        windowManager: WindowManager,
        environmentStore: EnvironmentStore,
        onShowPlans: (() -> Void)?,
        onShowMemories: (() -> Void)?,
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
        if trimmedLower == "/usage" {
            awaitingUsageStats = true
            connection.getUsageStats(environmentId: currentConversation(windowManager: windowManager, conversationStore: conversationStore)?.environmentId ?? environmentStore.activeEnvironmentId)
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

        if conv.environmentId == nil {
            conversationStore.setEnvironmentId(conv, environmentId: activeWindowEnvironmentId(windowManager: windowManager, conversationStore: conversationStore, environmentStore: environmentStore))
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
            let effortValue = (currentEffort ?? conv.defaultEffort)?.rawValue
            let modelValue = (currentModel ?? conv.defaultModel)?.rawValue
            connection.sendChat(
                text,
                workingDirectory: conv.workingDirectory,
                sessionId: conv.sessionId,
                isNewSession: isNewSession,
                conversationId: conv.id,
                imagesBase64: imagesBase64,
                filesBase64: filesBase64,
                conversationName: conv.name,
                conversationSymbol: conv.symbol,
                forkSession: isFork,
                effort: effortValue,
                model: modelValue,
                environmentId: conv.environmentId
            )

            connection.output(for: conv.id).liveMessageId = conversationStore.insertLiveMessage(into: conv)

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

    func exportConversation(_ conversation: Conversation, conversationStore: ConversationStore) {
        var lines: [String] = []
        let messages = conversationStore.messages(for: conversation)
        for message in messages {
            if message.isUser {
                lines.append("**User**: \(message.text)")
            } else {
                var parts: [String] = []
                let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    parts.append(text)
                }
                for tool in message.toolCalls {
                    parts.append("> **\(tool.name)**: \(tool.input ?? "")")
                }
                lines.append(parts.joined(separator: "\n\n"))
            }
        }
        UIPasteboard.general.string = lines.joined(separator: "\n\n---\n\n")
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
