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

        if let liveId = output.liveMessageId {
            if trimmedText.isEmpty && adjustedToolCalls.isEmpty {
                AppLogger.connectionInfo("finalize live message remove convId=\(freshConv.id.uuidString) liveId=\(liveId.uuidString)")
                removeMessage(liveId, from: freshConv)
            } else {
                AppLogger.connectionInfo("finalize live message update convId=\(freshConv.id.uuidString) liveId=\(liveId.uuidString) chars=\(trimmedText.count) tools=\(adjustedToolCalls.count)")
                updateMessage(liveId, in: freshConv) { msg in
                    msg.text = trimmedText
                    msg.toolCalls = adjustedToolCalls
                    msg.durationMs = output.runStats?.durationMs
                    msg.costUsd = output.runStats?.costUsd
                    msg.serverUUID = output.messageUUID
                    msg.model = output.runStats?.model
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
                addMessage(message, to: conversation)
            }
            output.reset()
        }

        if let cost = output.runStats?.costUsd, cost > 0 {
            let convId = conversation.id
            mutate(convId) { conv in
                let computed = conv.messages.compactMap(\.costUsd).reduce(0, +)
                conv.savedTotalCost = max(computed, conv.savedTotalCost ?? 0)
            }
        }
    }

    func replayQueuedMessages(conversation: Conversation, connection: ConnectionManager) {
        guard connection.isAuthenticated else { return }

        let freshConv = self.conversation(withId: conversation.id) ?? conversation

        let pending = popPendingMessages(from: freshConv)
        guard !pending.isEmpty else { return }
        AppLogger.connectionInfo("replay queued messages convId=\(freshConv.id.uuidString) count=\(pending.count)")

        for var msg in pending {
            msg.isQueued = false
            addMessage(msg, to: freshConv)
        }

        let combinedText = pending.map { $0.text }.joined(separator: "\n\n")
        let updatedConv = self.conversation(withId: conversation.id) ?? freshConv

        connection.sendChat(
            combinedText,
            workingDirectory: updatedConv.workingDirectory,
            sessionId: updatedConv.sessionId,
            isNewSession: false,
            conversationId: updatedConv.id,
            conversationName: updatedConv.name,
            conversationSymbol: updatedConv.symbol,
            environmentId: updatedConv.environmentId
        )
    }
}
