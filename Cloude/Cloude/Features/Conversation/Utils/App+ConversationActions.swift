import Foundation
import UIKit
import CloudeShared

extension App {
    func activeConversation() -> Conversation? {
        windowManager.activeWindow?.conversation(in: conversationStore)
    }

    func selectConversation(id: UUID) {
        if let conversation = conversationStore.conversation(withId: id),
           let activeWindow = windowManager.ensureActiveWindow() {
            windowManager.selectConversation(
                conversation,
                in: activeWindow.id,
                conversationStore: conversationStore
            )
            AppLogger.bootstrapInfo("selected conversation convId=\(id.uuidString) windowId=\(activeWindow.id.uuidString)")
        } else {
            AppLogger.bootstrapInfo("select conversation failed convId=\(id.uuidString)")
        }
    }

    func createNewConversation(path: String? = nil) {
        let current = activeConversation()
        let environmentId = windowManager.activeWindow?.runtimeEnvironmentId(
            conversationStore: conversationStore,
            environmentStore: environmentStore
        ).flatMap {
            environmentStore.connectionStore.connection(for: $0) == nil ? nil : $0
        }

        if let activeWindow = windowManager.ensureActiveWindow() {
            let conversation = conversationStore.newConversation(
                workingDirectory: path?.nilIfEmpty ?? current?.workingDirectory,
                environmentId: environmentId
            )
            windowManager.linkToCurrentConversation(activeWindow.id, conversation: conversation)
            AppLogger.bootstrapInfo(
                "created new conversation convId=\(conversation.id.uuidString) windowId=\(activeWindow.id.uuidString) path=\(conversation.workingDirectory ?? "-")"
            )
        }
    }

    func duplicateActiveConversation() {
        if let conversation = activeConversation(),
           let duplicate = conversationStore.duplicateConversation(conversation),
           let activeWindow = windowManager.activeWindow {
            windowManager.linkToCurrentConversation(activeWindow.id, conversation: duplicate)
            AppLogger.bootstrapInfo("duplicated conversation source=\(conversation.id.uuidString) duplicate=\(duplicate.id.uuidString)")
        } else {
            AppLogger.bootstrapInfo("duplicate conversation ignored")
        }
    }

    func sendActiveConversationMessage(onShowSettings: (() -> Void)?) {
        let conversation = activeConversation()
        let text = conversation?.draft.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let images = conversation?.draft.images ?? []
        let files = conversation?.draft.files ?? []
        let allImagesBase64 = ConversationImageEncoder.encodeFullImages(images)
        let thumbnails = ConversationImageEncoder.encodeThumbnails(images)
        let allFilesBase64 = encodeAttachedFiles(files)

        if text.isEmpty && allImagesBase64 == nil && allFilesBase64 == nil {
            return
        }
        MessageHistory.save(text, symbol: conversation?.symbol)
        if let conversation {
            conversationStore.mutateDraft(conversation.id) { $0 = ConversationDraft() }
        }

        if text.lowercased().trimmingCharacters(in: .whitespaces) == "/settings" {
            onShowSettings?()
            return
        }

        sendConversationMessage(
            text: text,
            imagesBase64: allImagesBase64,
            filesBase64: allFilesBase64,
            thumbnails: thumbnails
        )
    }

    func refreshActiveConversation() {
        if let activeWindow = windowManager.activeWindow {
            refreshConversation(for: activeWindow)
        } else {
            AppLogger.bootstrapInfo("refresh conversation ignored")
        }
    }

    func refreshConversation(for window: Window) {
        if let convId = window.conversationId,
           let conversation = conversationStore.conversation(withId: convId),
           let sessionId = conversation.sessionId,
           let workingDirectory = conversation.workingDirectory,
           !workingDirectory.isEmpty {
            let messages = conversationStore.messages(for: conversation)
            if let lastUserIndex = messages.lastIndex(where: { $0.isUser }) {
                conversationStore.truncateMessages(for: conversation, from: lastUserIndex + 1)
            }
            AppLogger.beginInterval("conversation.refresh", key: conversation.id.uuidString, details: "sessionId=\(sessionId)")
            environmentStore.connectionStore.connection(for: conversation.environmentId)?.conversation(conversation.id).syncHistory(sessionId: sessionId, workingDirectory: workingDirectory)
        } else {
            AppLogger.bootstrapInfo("refresh conversation ignored")
        }
    }

    func refreshEditingConversation(for window: Window) async {
        refreshConversation(for: window)
        try? await Task.sleep(for: .seconds(1))
    }

    func stopActiveConversationRun() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if let conversation = activeConversation() {
            environmentStore.connectionStore.connection(for: conversation.environmentId)?.conversation(conversation.id).abort()
            AppLogger.bootstrapInfo("stop run convId=\(conversation.id.uuidString)")
        } else {
            AppLogger.bootstrapInfo("stop run ignored no active conversation")
        }
    }

    func stopActiveRun() {
        stopActiveConversationRun()
    }

    func setActiveConversationModel(_ value: String?) {
        if let conversation = activeConversation() {
            let model = value.flatMap(ModelSelection.init(rawValue:))
            conversationStore.setDefaultModel(conversation, model: model)
            AppLogger.bootstrapInfo("set conversation model convId=\(conversation.id.uuidString) model=\(model?.rawValue ?? "nil")")
        }
    }

    func setActiveConversationEffort(_ value: String?) {
        if let conversation = activeConversation() {
            let effort = value.flatMap(EffortLevel.init(rawValue:))
            conversationStore.setDefaultEffort(conversation, effort: effort)
            AppLogger.bootstrapInfo("set conversation effort convId=\(conversation.id.uuidString) effort=\(effort?.rawValue ?? "nil")")
        }
    }

    func sendDebugMessage(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty {
            AppLogger.bootstrapInfo("debug send ignored empty text")
            return
        }

        guard let activeWindow = windowManager.ensureActiveWindow() else {
            AppLogger.bootstrapInfo("debug send failed missing active window")
            return
        }

        var conversation = activeWindow.conversation(in: conversationStore)
        if conversation == nil {
            conversation = conversationStore.newConversation(environmentId: environmentStore.activeEnvironmentId)
            windowManager.linkToCurrentConversation(activeWindow.id, conversation: conversation)
            AppLogger.bootstrapInfo("debug send created conversation windowId=\(activeWindow.id.uuidString)")
        }
        if let conversation {
            if conversation.environmentId == nil && activeWindow.conversationId == nil {
                conversationStore.setEnvironmentId(conversation, environmentId: environmentStore.activeEnvironmentId)
            }
            let updatedConversation = conversationStore.conversation(withId: conversation.id) ?? conversation
            conversationStore.dispatchUserTurn(
                ChatMessage(kind: .user(), text: trimmedText),
                to: updatedConversation,
                environmentStore: environmentStore,
                effort: updatedConversation.defaultEffort?.rawValue,
                model: updatedConversation.defaultModel?.rawValue,
                source: "debug send"
            )
        } else {
            AppLogger.bootstrapInfo("debug send failed missing conversation")
        }
    }

    private func sendConversationMessage(
        text: String,
        imagesBase64: [String]?,
        filesBase64: [AttachedFilePayload]?,
        thumbnails: [String]?
    ) {
        guard let activeWindow = windowManager.ensureActiveWindow() else { return }
        let environmentId = activeWindow.runtimeEnvironmentId(
            conversationStore: conversationStore,
            environmentStore: environmentStore
        ) ?? environmentStore.activeEnvironmentId
        let connection = environmentStore.connectionStore.connection(for: environmentId)
        let workingDirectory = activeWindow.conversation(in: conversationStore)?.workingDirectory
            ?? connection?.defaultWorkingDirectory?.nilIfEmpty

        var conversation = activeWindow.conversation(in: conversationStore)
        if conversation == nil {
            conversation = conversationStore.newConversation(
                workingDirectory: workingDirectory,
                environmentId: environmentId
            )
            windowManager.linkToCurrentConversation(activeWindow.id, conversation: conversation)
        }
        if let conversation,
           conversation.environmentId == nil || environmentStore.connectionStore.connection(for: conversation.environmentId) == nil {
            conversationStore.setEnvironmentId(conversation, environmentId: environmentId)
        }
        if let conversation {
            let updatedConversation = conversationStore.conversation(withId: conversation.id) ?? conversation
            let userMessage = ChatMessage(
                kind: .user(),
                text: text,
                imageBase64: thumbnails?.first,
                imageThumbnails: thumbnails
            )
            conversationStore.dispatchUserTurn(
                userMessage,
                to: updatedConversation,
                environmentStore: environmentStore,
                imagesBase64: imagesBase64,
                filesBase64: filesBase64,
                effort: updatedConversation.defaultEffort?.rawValue,
                model: updatedConversation.defaultModel?.rawValue,
                source: "user message"
            )
        }
    }

    private func encodeAttachedFiles(_ files: [AttachedFile]) -> [AttachedFilePayload]? {
        files.isEmpty ? nil : files.map { AttachedFilePayload(name: $0.name, data: $0.data.base64EncodedString()) }
    }
}
