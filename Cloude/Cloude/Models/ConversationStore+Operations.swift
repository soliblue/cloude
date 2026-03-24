import Foundation

extension ConversationStore {
    @discardableResult
    func mutate(_ conversationId: UUID, _ mutation: (inout Conversation) -> Void) -> Bool {
        guard let idx = conversations.firstIndex(where: { $0.id == conversationId }) else { return false }
        mutation(&conversations[idx])
        saveConversation(conversations[idx])
        return true
    }

    func findConversation(withId id: UUID) -> Conversation? {
        conversations.first { $0.id == id }
    }

    func findConversation(withSessionId sessionId: String) -> Conversation? {
        conversations.first { $0.sessionId == sessionId }
    }

    func newConversation(workingDirectory: String? = nil, environmentId: UUID? = nil) -> Conversation {
        let conversation = Conversation(workingDirectory: workingDirectory, environmentId: environmentId)
        conversations.insert(conversation, at: 0)
        saveConversation(conversation)
        return conversation
    }

    func setEnvironmentId(_ conversation: Conversation, environmentId: UUID?) {
        mutate(conversation.id) { $0.environmentId = environmentId }
    }

    func addConversation(_ conversation: Conversation) {
        conversations.insert(conversation, at: 0)
        saveConversation(conversation)
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

    func setDefaultEffort(_ conversation: Conversation, effort: EffortLevel?) {
        mutate(conversation.id) { $0.defaultEffort = effort }
    }

    func setDefaultModel(_ conversation: Conversation, model: ModelSelection?) {
        mutate(conversation.id) { $0.defaultModel = model }
    }

    func deleteConversation(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        deleteConversationFile(conversation.id)
    }

    func duplicateConversation(_ conversation: Conversation) -> Conversation? {
        guard conversation.sessionId != nil else { return nil }
        let newConversation = Conversation(
            name: conversation.name,
            symbol: conversation.symbol,
            sessionId: conversation.sessionId,
            workingDirectory: conversation.workingDirectory,
            pendingFork: true,
            environmentId: conversation.environmentId
        )
        conversations.insert(newConversation, at: 0)
        saveConversation(newConversation)
        return newConversation
    }

    func clearPendingFork(_ conversation: Conversation) {
        mutate(conversation.id) { $0.pendingFork = false }
    }

    func attachBranch(_ conversation: Conversation, branch: String, worktreePath: String) {
        mutate(conversation.id) {
            $0.originalWorkingDirectory = $0.originalWorkingDirectory ?? $0.workingDirectory
            $0.attachedBranch = branch
            $0.worktreePath = worktreePath
            $0.workingDirectory = worktreePath
        }
    }

    func detachBranch(_ conversation: Conversation) {
        mutate(conversation.id) {
            if let original = $0.originalWorkingDirectory {
                $0.workingDirectory = original
            }
            $0.attachedBranch = nil
            $0.worktreePath = nil
            $0.originalWorkingDirectory = nil
        }
    }
}
