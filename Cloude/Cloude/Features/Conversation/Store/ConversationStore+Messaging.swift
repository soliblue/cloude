import Foundation
import CloudeShared

extension ConversationStore {
    func dispatchUserTurn(
        _ displayMessage: ChatMessage,
        to conversation: Conversation,
        environmentStore: EnvironmentStore,
        imagesBase64: [String]? = nil,
        filesBase64: [AttachedFilePayload]? = nil,
        effort: String? = nil,
        model: String? = nil,
        queueIfUnavailable: Bool = true,
        source: String
    ) {
        let freshConv = self.conversation(withId: conversation.id) ?? conversation
        let isRunning = (environmentStore.connectionStore
            .connection(for: freshConv.environmentId)?
            .conversation(freshConv.id)
            .output
            .phase ?? .idle) != .idle
        let isReady = environmentStore.connectionStore.connection(for: freshConv.environmentId)?.isReady == true

        if queueIfUnavailable, isRunning || !isReady {
            AppLogger.connectionInfo("\(source) queue convId=\(freshConv.id.uuidString) chars=\(displayMessage.text.count) running=\(isRunning) authenticated=\(isReady)")
            var queuedMessage = displayMessage
            queuedMessage.kind = .user(isQueued: true)
            queuedMessage.pendingImagesBase64 = imagesBase64
            queuedMessage.pendingFilesBase64 = filesBase64
            queueMessage(queuedMessage, to: freshConv)
            return
        }

        AppLogger.connectionInfo("\(source) send convId=\(freshConv.id.uuidString) chars=\(displayMessage.text.count) images=\(imagesBase64?.count ?? 0) files=\(filesBase64?.count ?? 0)")
        var sentMessage = displayMessage
        sentMessage.kind = .user()
        sentMessage.pendingImagesBase64 = nil
        sentMessage.pendingFilesBase64 = nil
        addMessage(sentMessage, to: freshConv)

        let updatedConv = self.conversation(withId: conversation.id) ?? freshConv
        let isFork = updatedConv.pendingFork
        let isNewSession = updatedConv.sessionId == nil && !isFork
        environmentStore.connectionStore.connection(for: updatedConv.environmentId)?.conversation(updatedConv.id).sendChat(
            displayMessage.text,
            workingDirectory: updatedConv.workingDirectory,
            sessionId: updatedConv.sessionId,
            isNewSession: isNewSession,
            imagesBase64: imagesBase64,
            filesBase64: filesBase64,
            conversationName: updatedConv.name,
            forkSession: isFork,
            effort: effort,
            model: model
        )

        environmentStore.connectionStore.connection(for: updatedConv.environmentId)?.conversation(updatedConv.id).output.liveMessageId = insertLiveMessage(into: updatedConv)

        if isNewSession {
            AppLogger.connectionInfo("\(source) request name suggestion convId=\(updatedConv.id.uuidString)")
            environmentStore.connectionStore.connection(for: updatedConv.environmentId)?.conversation(updatedConv.id).requestNameSuggestion(text: displayMessage.text, context: [])
        }

        if isFork {
            AppLogger.connectionInfo("\(source) clear pending fork convId=\(updatedConv.id.uuidString)")
            clearPendingFork(updatedConv)
        }
    }

    func finalizeStreamingMessage(output: ConversationOutput, conversation: Conversation) {
        output.flushBuffer()
        let freshConv = self.conversation(withId: conversation.id) ?? conversation

        let rawText = output.text
        let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let leadingTrimmed = rawText.count - rawText.drop(while: { $0.isWhitespace || $0.isNewline }).count
        let adjustedToolCalls = output.toolCalls.map { tool in
            var adjusted = tool
            if leadingTrimmed > 0, let pos = adjusted.textPosition {
                adjusted.textPosition = max(0, pos - leadingTrimmed)
            }
            if adjusted.state == .executing {
                adjusted.state = .complete
            }
            return adjusted
        }

        let fallbackLiveId = freshConv.messages.last?.isRecoverableLiveMessage == true ? freshConv.messages.last?.id : nil

        if let liveId = output.liveMessageId ?? fallbackLiveId {
            if trimmedText.isEmpty && adjustedToolCalls.isEmpty {
                AppLogger.connectionInfo("finalize live message remove convId=\(freshConv.id.uuidString) liveId=\(liveId.uuidString)")
                removeMessage(liveId, from: freshConv)
            } else {
                AppLogger.connectionInfo("finalize live message update convId=\(freshConv.id.uuidString) liveId=\(liveId.uuidString) chars=\(trimmedText.count) tools=\(adjustedToolCalls.count)")
                let runStats = output.runStats
                let messageUUID = output.messageUUID
                mutate(freshConv.id) { conv in
                    if let msgIdx = conv.messages.firstIndex(where: { $0.id == liveId }) {
                        conv.messages[msgIdx].text = trimmedText
                        conv.messages[msgIdx].toolCalls = adjustedToolCalls
                        conv.messages[msgIdx].durationMs = runStats?.durationMs
                        conv.messages[msgIdx].costUsd = runStats?.costUsd
                        conv.messages[msgIdx].serverUUID = messageUUID
                        conv.messages[msgIdx].model = runStats?.model
                        conv.messages[msgIdx].kind = .assistant(wasInterrupted: false)
                    }
                    if let cost = runStats?.costUsd, cost > 0 {
                        let computed = conv.messages.compactMap(\.costUsd).reduce(0, +)
                        conv.savedTotalCost = max(computed, conv.savedTotalCost ?? 0)
                    }
                }
            }
            output.resetAfterLiveMessageHandoff()
        } else if !trimmedText.isEmpty {
            let isDuplicate: Bool
            if let uuid = output.messageUUID {
                isDuplicate = freshConv.messages.contains { $0.serverUUID == uuid }
            } else {
                isDuplicate = freshConv.messages.contains { !$0.isUser && $0.text == trimmedText && abs($0.timestamp.timeIntervalSinceNow) < 5 }
            }
            if !isDuplicate {
                AppLogger.connectionInfo("finalize assistant message add convId=\(conversation.id.uuidString) chars=\(trimmedText.count) tools=\(adjustedToolCalls.count)")
                let message = ChatMessage(
                    kind: .assistant(),
                    text: trimmedText,
                    toolCalls: adjustedToolCalls,
                    durationMs: output.runStats?.durationMs,
                    costUsd: output.runStats?.costUsd,
                    serverUUID: output.messageUUID,
                    model: output.runStats?.model
                )
                mutate(conversation.id) { conv in
                    conv.messages.append(message)
                    conv.lastMessageAt = Date()
                    if let cost = message.costUsd, cost > 0 {
                        let computed = conv.messages.compactMap(\.costUsd).reduce(0, +)
                        conv.savedTotalCost = max(computed, conv.savedTotalCost ?? 0)
                    }
                }
            }
            output.reset()
        }
    }

    func replayQueuedMessages(conversation: Conversation, environmentStore: EnvironmentStore) {
        guard environmentStore.connectionStore.connection(for: conversation.environmentId)?.isReady == true else { return }

        let freshConv = self.conversation(withId: conversation.id) ?? conversation
        guard let queuedMessage = freshConv.pendingMessages.first else { return }
        AppLogger.connectionInfo("replay queued messages convId=\(freshConv.id.uuidString) count=\(freshConv.pendingMessages.count)")

        mutate(freshConv.id) {
            if !$0.pendingMessages.isEmpty {
                $0.pendingMessages.removeFirst()
            }
        }

        let updatedConv = self.conversation(withId: conversation.id) ?? freshConv
        let replayedMessage = ChatMessage(
            kind: .user(),
            text: queuedMessage.text,
            timestamp: queuedMessage.timestamp,
            imageBase64: queuedMessage.imageBase64,
            imageThumbnails: queuedMessage.imageThumbnails
        )
        dispatchUserTurn(
            replayedMessage,
            to: updatedConv,
            environmentStore: environmentStore,
            imagesBase64: queuedMessage.pendingImagesBase64,
            filesBase64: queuedMessage.pendingFilesBase64,
            effort: updatedConv.defaultEffort?.rawValue,
            model: updatedConv.defaultModel?.rawValue,
            source: "replay queued messages"
        )
    }
}
