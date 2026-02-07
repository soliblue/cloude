import Foundation
import CloudeShared

extension ConversationStore {
    func finalizeStreamingMessage(output: ConversationOutput, conversation: Conversation) {
        guard !output.text.isEmpty else { return }

        let rawText = output.text
        let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let leadingTrimmed = rawText.count - rawText.drop(while: { $0.isWhitespace || $0.isNewline }).count
        let adjustedToolCalls = leadingTrimmed > 0 ? output.toolCalls.map { tool in
            var adjusted = tool
            if let pos = adjusted.textPosition {
                adjusted.textPosition = max(0, pos - leadingTrimmed)
            }
            return adjusted
        } : output.toolCalls

        var teamSummary: TeamSummary?
        if let teamName = output.teamName, !output.teammates.isEmpty {
            teamSummary = TeamSummary(
                teamName: teamName,
                members: output.teammates.map {
                    TeamSummary.Member(name: $0.name, color: $0.color, model: $0.model, agentType: $0.agentType)
                }
            )
        }

        let message = ChatMessage(
            isUser: false,
            text: trimmedText,
            toolCalls: adjustedToolCalls,
            durationMs: output.runStats?.durationMs,
            costUsd: output.runStats?.costUsd,
            serverUUID: output.messageUUID,
            teamSummary: teamSummary
        )

        let freshConv = self.conversation(withId: conversation.id) ?? conversation
        let isDuplicate: Bool
        if let uuid = output.messageUUID {
            isDuplicate = freshConv.messages.contains { $0.serverUUID == uuid }
        } else {
            isDuplicate = freshConv.messages.contains { !$0.isUser && $0.text == message.text && abs($0.timestamp.timeIntervalSinceNow) < 5 }
        }
        guard !isDuplicate else {
            output.reset()
            return
        }

        addMessage(message, to: conversation)
        output.reset()
    }

    func replayQueuedMessages(conversation: Conversation, connection: ConnectionManager) {
        guard connection.isAuthenticated else { return }

        let freshConv = self.conversation(withId: conversation.id) ?? conversation

        if let limit = freshConv.costLimitUsd, limit > 0, freshConv.totalCost >= limit {
            return
        }

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
            conversationSymbol: updatedConv.symbol
        )
    }
}
