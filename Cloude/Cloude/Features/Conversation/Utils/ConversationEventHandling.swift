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
                    message.kind = .assistant(wasInterrupted: true)
                }
                interruptedMessageId = liveId
            } else {
                conversationStore.removeMessage(liveId, from: conversation)
            }
        } else if hasContent, let conversation = conversationStore.findConversation(withId: conversationId) {
            let message = ChatMessage(kind: .assistant(wasInterrupted: true), text: trimmedText, toolCalls: output.toolCalls)
            conversationStore.addMessage(message, to: conversation)
            interruptedMessageId = message.id
        }

        if let sessionId = output.newSessionId,
           let envId = conversationStore.conversation(withId: conversationId)?.environmentId,
           let environmentConnection = environmentStore.connection(for: envId) {
            environmentConnection.interruptedSessions[sessionId] = InterruptedSession(conversationId: conversationId, messageId: interruptedMessageId)
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
                    kind: $0.isUser ? .user() : .assistant(),
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
                    if let output = environmentStore.connection(for: conversation.environmentId)?.output(for: conversation.id), output.phase == .idle {
                        output.reset()
                    }
                }
                if !environmentStore.isStreaming(for: conversation) {
                    conversationStore.replayQueuedMessages(conversation: updatedConversation, environmentStore: environmentStore)
                }
            }
        }
    }

    func handleTurnCompleted(conversationId: UUID) {
        guard var conversation = conversationStore.findConversation(withId: conversationId),
              let output = environmentStore.connection(for: conversation.environmentId)?.output(for: conversationId),
              output.phase == .idle else { return }
        let requiresHistoryResync = output.requiresHistoryResync

        if UIApplication.shared.applicationState != .active && !output.text.isEmpty {
            NotificationManager.showNotification(title: "Claude finished", body: output.text)
        }

        if let newSessionId = output.newSessionId {
            conversationStore.updateSessionId(conversation, sessionId: newSessionId, workingDirectory: conversation.workingDirectory)
            if let updatedConversation = conversationStore.findConversation(withId: conversationId) {
                conversation = updatedConversation
            }
        }

        let workingDirectory = conversation.workingDirectory
            ?? environmentStore.connection(for: conversation.environmentId)?.defaultWorkingDirectory
        let shouldSyncBeforeFinalize = requiresHistoryResync ||
            (output.liveMessageId != nil &&
             output.messageUUID == nil &&
             output.runStats != nil &&
             output.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
             output.toolCalls.isEmpty)
        AppLogger.connectionInfo("heuristic_counter=shouldSyncBeforeFinalize_eval convId=\(conversationId.uuidString) value=\(shouldSyncBeforeFinalize) requiresHistoryResync=\(requiresHistoryResync)")

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
            environmentStore.connection(for: conversation.environmentId)?.syncHistory(sessionId: sessionId, workingDirectory: workingDirectory)
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
            environmentStore.connection(for: conversation.environmentId)?.requestNameSuggestion(text: lastUserMessage, context: contextMessages, conversationId: conversation.id)
        }

        if requiresHistoryResync,
           let sessionId = updatedConversation.sessionId,
           let workingDirectory,
           !workingDirectory.isEmpty {
            AppLogger.connectionInfo("heuristic_counter=pendingHistorySyncMetadata_write phase=post_finalize convId=\(updatedConversation.id.uuidString)")
            conversationStore.pendingHistorySyncMetadata[updatedConversation.id] = (
                durationMs: output.runStats?.durationMs,
                costUsd: output.runStats?.costUsd,
                model: output.runStats?.model
            )
            environmentStore.connection(for: updatedConversation.environmentId)?.syncHistory(sessionId: sessionId, workingDirectory: workingDirectory)
        }

        conversationStore.replayQueuedMessages(conversation: updatedConversation, environmentStore: environmentStore)
    }

    func handleDeleteConversation(conversationId: UUID) {
        if let conversation = conversationStore.findConversation(withId: conversationId) {
            conversationStore.deleteConversation(conversation)
        }
    }

    func handleResumeBegin(conversationId: UUID, messageId: UUID) {
        guard let conversation = conversationStore.findConversation(withId: conversationId) else { return }
        conversationStore.updateMessage(messageId, in: conversation) { message in
            message.kind = .assistant(wasInterrupted: false)
        }
    }

    func handleLiveSnapshot(conversationId: UUID) {
        guard let conversation = conversationStore.findConversation(withId: conversationId),
              let output = environmentStore.connection(for: conversation.environmentId)?.output(for: conversationId),
              let liveId = output.liveMessageId,
              let message = conversation.messages.first(where: { $0.id == liveId }) else { return }
        if message.text != output.text || message.toolCalls != output.toolCalls {
            conversationStore.updateMessage(liveId, in: conversation) {
                $0.text = output.text
                $0.toolCalls = output.toolCalls
            }
        }
    }
}
