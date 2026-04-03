import Foundation
import Combine
import CloudeShared

extension App {
    func handleMissedResponse(text: String, storedToolCalls: [StoredToolCall], interruptedConvId: UUID?, interruptedMsgId: UUID?) {
        let toolCalls = storedToolCalls.map { ToolCall(from: $0) }
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let convId = interruptedConvId,
           let conv = conversationStore.findConversation(withId: convId) {
            if let msgId = interruptedMsgId,
               conv.messages.contains(where: { $0.id == msgId }) {
                conversationStore.updateMessage(msgId, in: conv) { msg in
                    msg.text = trimmedText
                    msg.toolCalls = toolCalls
                    msg.wasInterrupted = false
                }
            } else if !trimmedText.isEmpty,
                      !conv.messages.contains(where: { !$0.isUser && $0.text == trimmedText }) {
                conversationStore.addMessage(ChatMessage(isUser: false, text: trimmedText, toolCalls: toolCalls), to: conv)
            }
            conversationStore.objectWillChange.send()
        } else if let conversation = windowManager.activeWindow?.conversation(in: conversationStore),
                  !trimmedText.isEmpty,
                  !conversation.messages.contains(where: { !$0.isUser && $0.text == trimmedText }) {
            conversationStore.addMessage(ChatMessage(isUser: false, text: trimmedText, toolCalls: toolCalls), to: conversation)
        }
    }

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
            environmentConnection.interruptedSession = (conversationId, sessionId, interruptedMessageId ?? UUID())
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
        }
    }

    func handleDeleteConversation(conversationId: UUID) {
        if let conversation = conversationStore.findConversation(withId: conversationId) {
            conversationStore.deleteConversation(conversation)
        }
    }

    func handleReconnectRunning(conversationId: UUID) {
        if let conversation = conversationStore.findConversation(withId: conversationId),
           let lastMsg = conversation.messages.last, !lastMsg.isUser, lastMsg.wasInterrupted {
            let output = connection.output(for: conversationId)
            output.liveMessageId = lastMsg.id
            output.seedForReconnect(lastMsg.text, toolCalls: lastMsg.toolCalls)
            conversationStore.updateMessage(lastMsg.id, in: conversation) { $0.wasInterrupted = false }
        }
    }
}
