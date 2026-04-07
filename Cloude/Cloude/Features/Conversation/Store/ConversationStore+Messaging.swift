import Foundation
import CloudeShared

extension ConversationStore {
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
                    isUser: false,
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

    func replayQueuedMessages(conversation: Conversation, connection: ConnectionManager) {
        guard connection.isAuthenticated else { return }

        let freshConv = self.conversation(withId: conversation.id) ?? conversation
        guard let queuedMessage = freshConv.pendingMessages.first else { return }
        AppLogger.connectionInfo("replay queued messages convId=\(freshConv.id.uuidString) count=\(freshConv.pendingMessages.count)")

        mutate(freshConv.id) {
            if !$0.pendingMessages.isEmpty {
                $0.pendingMessages.removeFirst()
            }
        }

        var replayedMessage = queuedMessage
        replayedMessage.isQueued = false
        addMessage(replayedMessage, to: freshConv)

        let updatedConv = self.conversation(withId: conversation.id) ?? freshConv

        connection.sendChat(
            replayedMessage.text,
            workingDirectory: updatedConv.workingDirectory,
            sessionId: updatedConv.sessionId,
            isNewSession: false,
            conversationId: updatedConv.id,
            conversationName: updatedConv.name,
            conversationSymbol: updatedConv.symbol,
            effort: updatedConv.defaultEffort?.rawValue,
            model: updatedConv.defaultModel?.rawValue,
            environmentId: updatedConv.environmentId
        )

        connection.output(for: updatedConv.id).liveMessageId = insertLiveMessage(into: updatedConv)
    }
}
