import Foundation

extension ConversationStore {
    @discardableResult
    private func mutate(_ conversationId: UUID, _ mutation: (inout Conversation) -> Void) -> Bool {
        guard let idx = conversations.firstIndex(where: { $0.id == conversationId }) else { return false }
        mutation(&conversations[idx])
        if currentConversation?.id == conversationId {
            currentConversation = conversations[idx]
        }
        save()
        return true
    }

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
        var conversation = Conversation(workingDirectory: workingDirectory)
        let defaultLimit = UserDefaults.standard.double(forKey: "defaultCostLimitUsd")
        if defaultLimit > 0 {
            conversation.costLimitUsd = defaultLimit
        }
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
        mutate(conversation.id) {
            $0.messages.append(message)
            $0.lastMessageAt = Date()
        }
    }

    func updateSessionId(_ conversation: Conversation, sessionId: String, workingDirectory: String?) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        guard conversations[idx].sessionId != sessionId || conversations[idx].workingDirectory != workingDirectory else { return }
        mutate(conversation.id) {
            $0.sessionId = sessionId
            if $0.workingDirectory == nil, let wd = workingDirectory {
                $0.workingDirectory = wd
            }
        }
    }

    func renameConversation(_ conversation: Conversation, to name: String) {
        mutate(conversation.id) { $0.name = name }
    }

    func setConversationSymbol(_ conversation: Conversation, symbol: String?) {
        mutate(conversation.id) { $0.symbol = symbol }
    }

    func setWorkingDirectory(_ conversation: Conversation, path: String) {
        mutate(conversation.id) { $0.workingDirectory = path }
    }

    func setDefaultEffort(_ conversation: Conversation, effort: EffortLevel) {
        mutate(conversation.id) { $0.defaultEffort = effort }
    }

    func setDefaultModel(_ conversation: Conversation, model: ModelSelection?) {
        mutate(conversation.id) { $0.defaultModel = model }
    }

    func setCostLimit(_ conversation: Conversation, limit: Double?) {
        mutate(conversation.id) { $0.costLimitUsd = limit }
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
        mutate(conversation.id) { $0.pendingFork = false }
    }

    func updateMessage(_ messageId: UUID, in conversation: Conversation, update: (inout ChatMessage) -> Void) {
        mutate(conversation.id) {
            if let msgIdx = $0.messages.firstIndex(where: { $0.id == messageId }) {
                update(&$0.messages[msgIdx])
            }
        }
    }

    func queueMessage(_ message: ChatMessage, to conversation: Conversation) {
        mutate(conversation.id) { $0.pendingMessages.append(message) }
    }

    func popPendingMessages(from conversation: Conversation) -> [ChatMessage] {
        guard let idx = conversations.firstIndex(where: { $0.id == conversation.id }) else { return [] }
        let pending = conversations[idx].pendingMessages
        mutate(conversation.id) { $0.pendingMessages = [] }
        return pending
    }

    func pendingMessageCount(in conversation: Conversation) -> Int {
        conversations.first(where: { $0.id == conversation.id })?.pendingMessages.count ?? 0
    }

    func removePendingMessage(_ messageId: UUID, from conversation: Conversation) {
        mutate(conversation.id) { $0.pendingMessages.removeAll { $0.id == messageId } }
    }

    func getQueuedMessages(in conversation: Conversation) -> [ChatMessage] {
        conversations.first(where: { $0.id == conversation.id })?.messages.filter { $0.isQueued } ?? []
    }

    func clearQueuedFlags(in conversation: Conversation) {
        mutate(conversation.id) {
            for i in $0.messages.indices where $0.messages[i].isQueued {
                $0.messages[i].isQueued = false
            }
        }
    }

    func replaceMessages(_ conversation: Conversation, with messages: [ChatMessage]) {
        mutate(conversation.id) {
            $0.messages = messages
            if let lastTimestamp = messages.last?.timestamp {
                $0.lastMessageAt = lastTimestamp
            }
        }
    }
}
