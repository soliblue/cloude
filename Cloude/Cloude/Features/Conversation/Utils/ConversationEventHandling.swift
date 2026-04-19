import Foundation
import Combine
import UIKit
import CloudeShared

extension App {
    func handleDisconnect(conversationId: UUID, output: ConversationOutput) {
        let trimmedText = output.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasContent = !trimmedText.isEmpty || !output.toolCalls.isEmpty
        var interruptedMessageId: UUID?

        if let liveId = output.liveMessageId, let conversation = conversationStore.findConversation(withId: conversationId) {
            if hasContent {
                conversationStore.updateMessage(liveId, in: conversation) { message in
                    message.text = trimmedText
                    message.toolCalls = output.toolCalls
                    message.wasInterrupted = true
                }
                interruptedMessageId = liveId
            } else {
                conversationStore.removeMessage(liveId, from: conversation)
            }
        } else if hasContent, let conversation = conversationStore.findConversation(withId: conversationId) {
            let message = ChatMessage(isUser: false, text: trimmedText, toolCalls: output.toolCalls, wasInterrupted: true)
            conversationStore.addMessage(message, to: conversation)
            interruptedMessageId = message.id
        }

        if let sessionId = output.newSessionId,
           let environmentConnection = connection.connectionForConversation(conversationId) {
            environmentConnection.interruptedSessions[sessionId] = (conversationId, interruptedMessageId)
        }
    }

    func handleRenameConversation(conversationId: UUID, name: String) {
        if let conversation = conversationStore.findConversation(withId: conversationId) {
            conversationStore.renameConversation(conversation, to: name)
        }
    }

    func handleSetConversationSymbol(conversationId: UUID, symbol: String?) {
        if let conversation = conversationStore.findConversation(withId: conversationId) {
            conversationStore.setConversationSymbol(conversation, symbol: symbol)
        }
    }

    func handleSessionIdReceived(conversationId: UUID, sessionId: String) {
        if let conversation = conversationStore.findConversation(withId: conversationId) {
            conversationStore.updateSessionId(conversation, sessionId: sessionId, workingDirectory: conversation.workingDirectory)
        }
    }

    func handleHistorySync(sessionId: String, historyMessages: [HistoryMessage]) {
        if let conversation = conversationStore.findConversation(withSessionId: sessionId) {
            let newMessages = historyMessages.map {
                ChatMessage(
                    isUser: $0.isUser,
                    text: $0.text,
                    timestamp: $0.timestamp,
                    toolCalls: $0.toolCalls.map { ToolCall(from: $0) },
                    serverUUID: $0.serverUUID,
                    model: $0.model
                )
            }
            conversationStore.replaceMessages(conversation, with: newMessages)
            if let updatedConversation = conversationStore.findConversation(withId: conversation.id) {
                if let metadata = conversationStore.pendingHistorySyncMetadata.removeValue(forKey: conversation.id),
                   let lastAssistant = updatedConversation.messages.last(where: { !$0.isUser }) {
                    conversationStore.updateMessage(lastAssistant.id, in: updatedConversation) { message in
                        if message.durationMs == nil { message.durationMs = metadata.durationMs }
                        if message.costUsd == nil { message.costUsd = metadata.costUsd }
                        if message.model == nil { message.model = metadata.model }
                    }
                    let output = connection.output(for: conversation.id)
                    if !output.isRunning {
                        output.reset()
                    }
                }
                if !connection.output(for: conversation.id).isRunning {
                    conversationStore.replayQueuedMessages(conversation: updatedConversation, connection: connection)
                }
            }
        }
    }

    func handleTurnCompleted(conversationId: UUID) {
        let output = connection.output(for: conversationId)
        if output.isRunning { return }
        let needsHistorySync = output.needsHistorySync

        if UIApplication.shared.applicationState != .active && !output.text.isEmpty {
            NotificationManager.showCompletionNotification(preview: output.text)
        }

        guard var conversation = conversationStore.findConversation(withId: conversationId) else { return }

        if let newSessionId = output.newSessionId {
            conversationStore.updateSessionId(conversation, sessionId: newSessionId, workingDirectory: conversation.workingDirectory)
            if let updatedConversation = conversationStore.findConversation(withId: conversationId) {
                conversation = updatedConversation
            }
        }

        let workingDirectory = conversation.workingDirectory
            ?? connection.connection(for: conversation.environmentId)?.defaultWorkingDirectory
        let shouldSyncBeforeFinalize = needsHistorySync ||
            (output.liveMessageId != nil &&
             output.messageUUID == nil &&
             output.runStats != nil &&
             output.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
             output.toolCalls.isEmpty)
        AppLogger.connectionInfo("heuristic_counter=shouldSyncBeforeFinalize_eval convId=\(conversationId.uuidString) value=\(shouldSyncBeforeFinalize) needsHistorySync=\(needsHistorySync)")

        if shouldSyncBeforeFinalize,
           output.liveMessageId != nil,
           let sessionId = conversation.sessionId,
           let workingDirectory,
           !workingDirectory.isEmpty {
            if let liveId = output.liveMessageId {
                conversationStore.updateMessage(liveId, in: conversation) { message in
                    let trimmedText = output.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedText.isEmpty {
                        message.text = trimmedText
                    }
                    if !output.toolCalls.isEmpty {
                        message.toolCalls = output.toolCalls
                    }
                }
            }
            AppLogger.connectionInfo("heuristic_counter=pendingHistorySyncMetadata_write phase=pre_sync convId=\(conversation.id.uuidString)")
            conversationStore.pendingHistorySyncMetadata[conversation.id] = (
                durationMs: output.runStats?.durationMs,
                costUsd: output.runStats?.costUsd,
                model: output.runStats?.model
            )
            connection.syncHistory(sessionId: sessionId, workingDirectory: workingDirectory, environmentId: conversation.environmentId)
            return
        }

        conversationStore.finalizeStreamingMessage(output: output, conversation: conversation)

        let updatedConversation = conversationStore.findConversation(withId: conversation.id) ?? conversation
        let assistantCount = updatedConversation.messages.filter { !$0.isUser }.count
        let shouldRename = assistantCount == 2 || (assistantCount > 0 && assistantCount % 5 == 0)
        if shouldRename {
            let contextMessages = updatedConversation.messages.suffix(10).map {
                ($0.isUser ? "User: " : "Assistant: ") + String($0.text.prefix(300))
            }
            let lastUserMessage = updatedConversation.messages.last(where: { $0.isUser })?.text ?? ""
            connection.requestNameSuggestion(text: lastUserMessage, context: contextMessages, conversationId: conversation.id)
        }

        if needsHistorySync,
           let sessionId = updatedConversation.sessionId,
           let workingDirectory,
           !workingDirectory.isEmpty {
            AppLogger.connectionInfo("heuristic_counter=pendingHistorySyncMetadata_write phase=post_finalize convId=\(updatedConversation.id.uuidString)")
            conversationStore.pendingHistorySyncMetadata[updatedConversation.id] = (
                durationMs: output.runStats?.durationMs,
                costUsd: output.runStats?.costUsd,
                model: output.runStats?.model
            )
            connection.syncHistory(sessionId: sessionId, workingDirectory: workingDirectory, environmentId: updatedConversation.environmentId)
        }

        conversationStore.replayQueuedMessages(conversation: updatedConversation, connection: connection)
    }

    func handleDeleteConversation(conversationId: UUID) {
        if let conversation = conversationStore.findConversation(withId: conversationId) {
            conversationStore.deleteConversation(conversation)
        }
    }

    func handleResumeBegin(conversationId: UUID, messageId: UUID) {
        guard let conversation = conversationStore.findConversation(withId: conversationId) else { return }
        conversationStore.updateMessage(messageId, in: conversation) { message in
            message.wasInterrupted = false
        }
    }

    func handleLiveSnapshot(conversationId: UUID) {
        let output = connection.output(for: conversationId)
        guard let liveId = output.liveMessageId,
              let conversation = conversationStore.findConversation(withId: conversationId),
              let message = conversation.messages.first(where: { $0.id == liveId }) else { return }
        if message.text != output.text || message.toolCalls != output.toolCalls {
            conversationStore.updateMessage(liveId, in: conversation) {
                $0.text = output.text
                $0.toolCalls = output.toolCalls
            }
        }
    }
}
