import Foundation
import CloudeShared

extension App {
    func endRefreshInterval(sessionId: String) {
        AppLogger.endInterval("conversation.refresh", key: conversationStore.findConversation(withSessionId: sessionId)?.id.uuidString, details: "sessionId=\(sessionId)")
    }

    func replayQueuedMessagesIfNeeded(environmentId: UUID) {
        for conversation in conversationStore.conversations where !conversation.pendingMessages.isEmpty {
            if conversation.environmentId == environmentId,
               (environmentStore.connectionStore
                .connection(for: conversation.environmentId)?
                .conversation(conversation.id)
                .output
                .phase ?? .idle) == .idle,
               conversation.messages.last?.isRecoverableLiveMessage != true {
                conversationStore.replayQueuedMessages(conversation: conversation, environmentStore: environmentStore)
            }
        }
    }

    func recoverInterruptedMessagesIfNeeded(environmentId: UUID) {
        for conversation in conversationStore.conversations {
            if let lastMessage = conversation.messages.last,
               conversation.environmentId == environmentId,
               lastMessage.isRecoverableLiveMessage,
               let sessionId = conversation.sessionId,
               !sessionId.isEmpty,
               let connection = environmentStore.connectionStore.connection(for: conversation.environmentId),
               !connection.conversation(conversation.id).isTrackingInterruptedSession(sessionId) {
                connection.conversation(conversation.id).rememberInterruptedSession(sessionId: sessionId, messageId: lastMessage.id)
                connection.conversation(conversation.id).resume(sessionId: sessionId, lastSeq: 0)
            }
        }
    }

    func appendTranscriptionToActiveConversation(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isBlank = trimmed.isEmpty ||
            trimmed.contains("blank_audio") ||
            trimmed.contains("blank audio") ||
            trimmed.contains("silence") ||
            trimmed.contains("no speech") ||
            trimmed.contains("inaudible") ||
            trimmed == "you" ||
            trimmed == "thanks for watching"
        if !isBlank, let conversation = activeConversation() {
            conversationStore.mutateDraft(conversation.id) {
                $0.text = $0.text.isEmpty ? text : $0.text + " " + text
            }
        }
        AudioRecorder.clearPendingAudioFile()
    }

    func refreshGitStatusAfterTurn(conversationId: UUID) {
        if let conversation = conversationStore.conversation(withId: conversationId),
           let workingDirectory = conversation.workingDirectory,
           !workingDirectory.isEmpty {
            environmentStore.connectionStore.connection(for: conversation.environmentId)?.git.requestStatus(workingDirectory)
        }
    }

    func updateLastAssistantMessageCost(conversationId: UUID, costUsd: Double) {
        if let conversation = conversationStore.conversation(withId: conversationId),
           let lastAssistantMessage = conversation.messages.last(where: { !$0.isUser }),
           costUsd > 0,
           !lastAssistantMessage.isRecoverableLiveMessage {
            conversationStore.updateMessage(lastAssistantMessage.id, in: conversation) { message in
                message.costUsd = costUsd
            }
            conversationStore.mutate(conversationId) { conversation in
                let computed = conversation.messages.compactMap(\.costUsd).reduce(0, +)
                conversation.savedTotalCost = max(computed, conversation.savedTotalCost ?? 0)
            }
        }
    }
}
