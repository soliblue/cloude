import Foundation
import CloudeShared

extension WorkspaceStore {
    func handleConnectionEvent(_ event: ConnectionEvent, environmentStore: EnvironmentStore, conversationStore: ConversationStore) {
        switch event {
        case .historySync(let sessionId, _), .historySyncError(let sessionId, _):
            AppLogger.endInterval("conversation.refresh", key: conversationStore.findConversation(withSessionId: sessionId)?.id.uuidString, details: "sessionId=\(sessionId)")
        case .authenticated(let environmentId):
            recoverInterruptedMessagesIfNeeded(environmentId: environmentId, environmentStore: environmentStore, conversationStore: conversationStore)
            replayQueuedMessagesIfNeeded(environmentId: environmentId, environmentStore: environmentStore, conversationStore: conversationStore)
        case .transcription(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let isBlank = trimmed.isEmpty ||
                trimmed.contains("blank_audio") ||
                trimmed.contains("blank audio") ||
                trimmed.contains("silence") ||
                trimmed.contains("no speech") ||
                trimmed.contains("inaudible") ||
                trimmed == "you" ||
                trimmed == "thanks for watching"
            if !isBlank {
                inputText = inputText.isEmpty ? text : inputText + " " + text
            }
            AudioRecorder.clearPendingAudioFile()
        case .turnCompleted(let convId):
            if let conv = conversationStore.conversation(withId: convId),
               let dir = conv.workingDirectory,
               !dir.isEmpty {
                environmentStore.connection(for: conv.environmentId)?.git.requestStatus(dir)
            }
        case .lastAssistantMessageCostUpdate(let convId, let costUsd):
            if let conversation = conversationStore.conversation(withId: convId),
               let lastAssistantMsg = conversation.messages.last(where: { !$0.isUser }),
               costUsd > 0,
               !lastAssistantMsg.isRecoverableLiveMessage {
                conversationStore.updateMessage(lastAssistantMsg.id, in: conversation) { msg in
                    msg.costUsd = costUsd
                }
                conversationStore.mutate(convId) { conv in
                    let computed = conv.messages.compactMap(\.costUsd).reduce(0, +)
                    conv.savedTotalCost = max(computed, conv.savedTotalCost ?? 0)
                }
            }
        default:
            break
        }
    }

    func replayQueuedMessagesIfNeeded(environmentId: UUID, environmentStore: EnvironmentStore, conversationStore: ConversationStore) {
        for conv in conversationStore.conversations where !conv.pendingMessages.isEmpty {
            if conv.environmentId == environmentId,
               !environmentStore.isStreaming(for: conv),
               conv.messages.last?.isRecoverableLiveMessage != true {
                conversationStore.replayQueuedMessages(conversation: conv, environmentStore: environmentStore)
            }
        }
    }

    func recoverInterruptedMessagesIfNeeded(environmentId: UUID, environmentStore: EnvironmentStore, conversationStore: ConversationStore) {
        for conv in conversationStore.conversations {
            if let lastMessage = conv.messages.last,
               conv.environmentId == environmentId,
               lastMessage.isRecoverableLiveMessage,
               let sessionId = conv.sessionId,
               !sessionId.isEmpty,
               let environmentConnection = environmentStore.connection(for: conv.environmentId),
               environmentConnection.interruptedSessions[sessionId] == nil {
                environmentConnection.interruptedSessions[sessionId] = InterruptedSession(conversationId: conv.id, messageId: lastMessage.id)
                environmentConnection.send(.resumeFrom(sessionId: sessionId, lastSeq: 0))
            }
        }
    }
}
