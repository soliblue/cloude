import Foundation
import CloudeShared

extension ConversationStore {
    func finalizeStreamingMessage(output: ConversationOutput, conversation: Conversation) {
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

        var teamSummary: TeamSummary?
        if let teamName = output.teamName, !output.teammates.isEmpty {
            teamSummary = TeamSummary(
                teamName: teamName,
                members: output.teammates.map {
                    TeamSummary.Member(name: $0.name, color: $0.color, model: $0.model, agentType: $0.agentType)
                }
            )
        } else if let snapshot = output.teamSnapshot {
            teamSummary = TeamSummary(
                teamName: snapshot.name,
                members: snapshot.members.map {
                    TeamSummary.Member(name: $0.name, color: $0.color, model: $0.model, agentType: $0.agentType)
                }
            )
        }

        if let liveId = output.liveMessageId {
            if trimmedText.isEmpty && adjustedToolCalls.isEmpty {
                removeMessage(liveId, from: freshConv)
            } else {
                updateMessage(liveId, in: freshConv) { msg in
                    msg.text = trimmedText
                    msg.toolCalls = adjustedToolCalls
                    msg.durationMs = output.runStats?.durationMs
                    msg.costUsd = output.runStats?.costUsd
                    msg.serverUUID = output.messageUUID
                    msg.model = output.runStats?.model
                    msg.teamSummary = teamSummary
                }
            }
            output.liveMessageId = nil
        } else if !trimmedText.isEmpty {
            let isDuplicate: Bool
            if let uuid = output.messageUUID {
                isDuplicate = freshConv.messages.contains { $0.serverUUID == uuid }
            } else {
                isDuplicate = freshConv.messages.contains { !$0.isUser && $0.text == trimmedText && abs($0.timestamp.timeIntervalSinceNow) < 5 }
            }
            if !isDuplicate {
                let message = ChatMessage(
                    isUser: false,
                    text: trimmedText,
                    toolCalls: adjustedToolCalls,
                    durationMs: output.runStats?.durationMs,
                    costUsd: output.runStats?.costUsd,
                    serverUUID: output.messageUUID,
                    teamSummary: teamSummary,
                    model: output.runStats?.model
                )
                addMessage(message, to: conversation)
            }
            output.reset()
        }
    }

    func replayQueuedMessages(conversation: Conversation, connection: ConnectionManager) {
        guard connection.isAuthenticated else { return }

        let freshConv = self.conversation(withId: conversation.id) ?? conversation

        let pending = popPendingMessages(from: freshConv)
        guard !pending.isEmpty else { return }

        for var msg in pending {
            msg.isQueued = false
            addMessage(msg, to: freshConv)
        }

        let combinedText = pending.map { $0.text }.joined(separator: "\n\n")
        let updatedConv = self.conversation(withId: conversation.id) ?? freshConv
        let isHeartbeat = conversation.id == Heartbeat.conversationId

        connection.sendChat(
            combinedText,
            workingDirectory: isHeartbeat ? nil : updatedConv.workingDirectory,
            sessionId: isHeartbeat ? Heartbeat.sessionId : updatedConv.sessionId,
            isNewSession: false,
            conversationId: updatedConv.id,
            conversationName: updatedConv.name,
            conversationSymbol: updatedConv.symbol,
            environmentId: updatedConv.environmentId
        )
    }
}
