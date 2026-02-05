import Foundation

extension ConversationStore {
    func findConversation(withId id: UUID) -> Conversation? {
        conversations.first { $0.id == id }
    }

    func findConversation(withSessionId sessionId: String) -> Conversation? {
        conversations.first { $0.sessionId == sessionId }
    }

    func selectConversation(_ conversation: Conversation) {
        currentConversation = conversations.first { $0.id == conversation.id }
    }

    func newConversation(workingDirectory: String? = nil) -> Conversation {
        let conversation = Conversation(workingDirectory: workingDirectory)
        conversations.insert(conversation, at: 0)
        currentConversation = conversation
        save()
        return conversation
    }

    func addConversation(_ conversation: Conversation) {
        conversations.insert(conversation, at: 0)
        currentConversation = conversation
        save()
    }

    func addMessage(_ message: ChatMessage, to conversation: Conversation) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        conversations[idx].messages.append(message)
        conversations[idx].lastMessageAt = Date()
        if currentConversation?.id == conversation.id {
            currentConversation = conversations[idx]
        }
        save()
    }

    func updateSessionId(_ conversation: Conversation, sessionId: String, workingDirectory: String?) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        guard conversations[idx].sessionId != sessionId || conversations[idx].workingDirectory != workingDirectory else { return }
        conversations[idx].sessionId = sessionId
        if conversations[idx].workingDirectory == nil, let wd = workingDirectory {
            conversations[idx].workingDirectory = wd
        }
        if currentConversation?.id == conversation.id {
            currentConversation = conversations[idx]
        }
        save()
    }

    func renameConversation(_ conversation: Conversation, to name: String) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        conversations[idx].name = name
        if currentConversation?.id == conversation.id {
            currentConversation = conversations[idx]
        }
        save()
    }

    func setConversationSymbol(_ conversation: Conversation, symbol: String?) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        conversations[idx].symbol = symbol
        if currentConversation?.id == conversation.id {
            currentConversation = conversations[idx]
        }
        save()
    }

    func setWorkingDirectory(_ conversation: Conversation, path: String) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        conversations[idx].workingDirectory = path
        if currentConversation?.id == conversation.id {
            currentConversation = conversations[idx]
        }
        save()
    }

    func deleteConversation(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        if currentConversation?.id == conversation.id {
            currentConversation = listableConversations.first
        }
        save()
    }

    func duplicateConversation(_ conversation: Conversation) -> Conversation? {
        guard conversation.sessionId != nil else { return nil }
        let newConversation = Conversation(
            name: conversation.name,
            symbol: conversation.symbol,
            sessionId: conversation.sessionId,
            workingDirectory: conversation.workingDirectory,
            pendingFork: true
        )
        conversations.insert(newConversation, at: 0)
        currentConversation = newConversation
        save()
        return newConversation
    }

    func clearPendingFork(_ conversation: Conversation) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        conversations[idx].pendingFork = false
        if currentConversation?.id == conversation.id {
            currentConversation = conversations[idx]
        }
        save()
    }

    func updateMessage(_ messageId: UUID, in conversation: Conversation, update: (inout ChatMessage) -> Void) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversation.id }),
              let msgIdx = conversations[idx].messages.firstIndex(where: { $0.id == messageId }) else { return }
        update(&conversations[idx].messages[msgIdx])
        if currentConversation?.id == conversation.id {
            currentConversation = conversations[idx]
        }
        save()
    }

    func queueMessage(_ message: ChatMessage, to conversation: Conversation) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        conversations[idx].pendingMessages.append(message)
        if currentConversation?.id == conversation.id {
            currentConversation = conversations[idx]
        }
        save()
    }

    func popPendingMessages(from conversation: Conversation) -> [ChatMessage] {
        guard let idx = conversations.firstIndex(where: { $0.id == conversation.id }) else { return [] }
        let pending = conversations[idx].pendingMessages
        conversations[idx].pendingMessages = []
        if currentConversation?.id == conversation.id {
            currentConversation = conversations[idx]
        }
        save()
        return pending
    }

    func pendingMessageCount(in conversation: Conversation) -> Int {
        guard let idx = conversations.firstIndex(where: { $0.id == conversation.id }) else { return 0 }
        return conversations[idx].pendingMessages.count
    }

    func removePendingMessage(_ messageId: UUID, from conversation: Conversation) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        conversations[idx].pendingMessages.removeAll { $0.id == messageId }
        if currentConversation?.id == conversation.id {
            currentConversation = conversations[idx]
        }
        save()
    }

    func getQueuedMessages(in conversation: Conversation) -> [ChatMessage] {
        guard let idx = conversations.firstIndex(where: { $0.id == conversation.id }) else { return [] }
        return conversations[idx].messages.filter { $0.isQueued }
    }

    func clearQueuedFlags(in conversation: Conversation) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        for i in conversations[idx].messages.indices {
            if conversations[idx].messages[i].isQueued {
                conversations[idx].messages[i].isQueued = false
            }
        }
        if currentConversation?.id == conversation.id {
            currentConversation = conversations[idx]
        }
        save()
    }

    func replaceMessages(_ conversation: Conversation, with messages: [ChatMessage]) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        conversations[idx].messages = messages
        if let lastTimestamp = messages.last?.timestamp {
            conversations[idx].lastMessageAt = lastTimestamp
        }
        if currentConversation?.id == conversation.id {
            currentConversation = conversations[idx]
        }
        save()
    }
}
