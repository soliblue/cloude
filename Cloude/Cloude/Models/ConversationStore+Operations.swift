//
//  ProjectStore+Conversation.swift
//  Cloude

import Foundation

extension ProjectStore {
    func findConversation(withId id: UUID) -> (Project, Conversation)? {
        for project in projects {
            if let conv = project.conversations.first(where: { $0.id == id }) {
                return (project, conv)
            }
        }
        return nil
    }

    func findConversation(withSessionId sessionId: String) -> (Project, Conversation)? {
        for project in projects {
            if let conv = project.conversations.first(where: { $0.sessionId == sessionId }) {
                return (project, conv)
            }
        }
        return nil
    }

    func selectConversation(_ conversation: Conversation, in project: Project) {
        currentProject = project
        currentConversation = conversation
    }

    func newConversation(in project: Project, workingDirectory: String? = nil) -> Conversation {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else {
            return Conversation()
        }
        let conversation = Conversation(workingDirectory: workingDirectory)
        projects[index].addConversation(conversation)
        currentProject = projects[index]
        currentConversation = conversation
        save()
        return conversation
    }

    func addMessage(_ message: ChatMessage, to conversation: Conversation, in project: Project) {
        guard let (projectIndex, convIndex) = findIndices(for: project, conversation: conversation) else { return }

        projects[projectIndex].conversations[convIndex].messages.append(message)
        projects[projectIndex].conversations[convIndex].lastMessageAt = Date()
        projects[projectIndex].lastMessageAt = Date()

        let updated = projects[projectIndex].conversations.remove(at: convIndex)
        projects[projectIndex].conversations.insert(updated, at: 0)

        currentProject = projects[projectIndex]
        if currentConversation?.id == conversation.id {
            currentConversation = projects[projectIndex].conversations[0]
        }
        save()
    }

    func updateSessionId(_ conversation: Conversation, in project: Project, sessionId: String, workingDirectory: String?) {
        guard let (projectIndex, convIndex) = findIndices(for: project, conversation: conversation) else { return }
        let conv = projects[projectIndex].conversations[convIndex]
        guard conv.sessionId != sessionId || conv.workingDirectory != workingDirectory else { return }
        projects[projectIndex].conversations[convIndex].sessionId = sessionId
        if conv.workingDirectory == nil, let wd = workingDirectory {
            projects[projectIndex].conversations[convIndex].workingDirectory = wd
        }
        currentProject = projects[projectIndex]
        if currentConversation?.id == conversation.id {
            currentConversation = projects[projectIndex].conversations[convIndex]
        }
        save()
    }

    func renameConversation(_ conversation: Conversation, in project: Project, to name: String) {
        guard let (projectIndex, convIndex) = findIndices(for: project, conversation: conversation) else { return }
        projects[projectIndex].conversations[convIndex].name = name
        currentProject = projects[projectIndex]
        if currentConversation?.id == conversation.id {
            currentConversation = projects[projectIndex].conversations[convIndex]
        }
        save()
    }

    func setConversationSymbol(_ conversation: Conversation, in project: Project, symbol: String?) {
        guard let (projectIndex, convIndex) = findIndices(for: project, conversation: conversation) else { return }
        projects[projectIndex].conversations[convIndex].symbol = symbol
        currentProject = projects[projectIndex]
        if currentConversation?.id == conversation.id {
            currentConversation = projects[projectIndex].conversations[convIndex]
        }
        save()
    }

    func setWorkingDirectory(_ conversation: Conversation, in project: Project, path: String) {
        guard let (projectIndex, convIndex) = findIndices(for: project, conversation: conversation) else { return }
        projects[projectIndex].conversations[convIndex].workingDirectory = path
        currentProject = projects[projectIndex]
        if currentConversation?.id == conversation.id {
            currentConversation = projects[projectIndex].conversations[convIndex]
        }
        save()
    }

    func deleteConversation(_ conversation: Conversation, from project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index].removeConversation(conversation)
        currentProject = projects[index]
        if currentConversation?.id == conversation.id {
            currentConversation = projects[index].conversations.first
        }
        save()
    }

    func duplicateConversation(_ conversation: Conversation, in project: Project) -> Conversation? {
        guard let index = projects.firstIndex(where: { $0.id == project.id }),
              conversation.sessionId != nil else { return nil }
        let newConversation = Conversation(
            name: conversation.name,
            symbol: conversation.symbol,
            sessionId: conversation.sessionId,
            workingDirectory: conversation.workingDirectory,
            pendingFork: true
        )
        projects[index].addConversation(newConversation)
        currentProject = projects[index]
        currentConversation = newConversation
        save()
        return newConversation
    }

    func clearPendingFork(_ conversation: Conversation, in project: Project) {
        guard let (projectIndex, convIndex) = findIndices(for: project, conversation: conversation) else { return }
        projects[projectIndex].conversations[convIndex].pendingFork = false
        currentProject = projects[projectIndex]
        if currentConversation?.id == conversation.id {
            currentConversation = projects[projectIndex].conversations[convIndex]
        }
        save()
    }

    func updateMessage(_ messageId: UUID, in conversation: Conversation, in project: Project, update: (inout ChatMessage) -> Void) {
        guard let (projectIndex, convIndex) = findIndices(for: project, conversation: conversation),
              let msgIndex = projects[projectIndex].conversations[convIndex].messages.firstIndex(where: { $0.id == messageId }) else {
            return
        }
        update(&projects[projectIndex].conversations[convIndex].messages[msgIndex])
        currentProject = projects[projectIndex]
        if currentConversation?.id == conversation.id {
            currentConversation = projects[projectIndex].conversations[convIndex]
        }
        save()
    }

    func queueMessage(_ message: ChatMessage, to conversation: Conversation, in project: Project) {
        guard let (projectIndex, convIndex) = findIndices(for: project, conversation: conversation) else { return }
        projects[projectIndex].conversations[convIndex].pendingMessages.append(message)
        currentProject = projects[projectIndex]
        if currentConversation?.id == conversation.id {
            currentConversation = projects[projectIndex].conversations[convIndex]
        }
        save()
    }

    func popPendingMessages(from conversation: Conversation, in project: Project) -> [ChatMessage] {
        guard let (projectIndex, convIndex) = findIndices(for: project, conversation: conversation) else { return [] }
        let pending = projects[projectIndex].conversations[convIndex].pendingMessages
        projects[projectIndex].conversations[convIndex].pendingMessages = []
        currentProject = projects[projectIndex]
        if currentConversation?.id == conversation.id {
            currentConversation = projects[projectIndex].conversations[convIndex]
        }
        save()
        return pending
    }

    func pendingMessageCount(in conversation: Conversation, in project: Project) -> Int {
        guard let (projectIndex, convIndex) = findIndices(for: project, conversation: conversation) else { return 0 }
        return projects[projectIndex].conversations[convIndex].pendingMessages.count
    }

    func removePendingMessage(_ messageId: UUID, from conversation: Conversation, in project: Project) {
        guard let (projectIndex, convIndex) = findIndices(for: project, conversation: conversation) else { return }
        projects[projectIndex].conversations[convIndex].pendingMessages.removeAll { $0.id == messageId }
        currentProject = projects[projectIndex]
        if currentConversation?.id == conversation.id {
            currentConversation = projects[projectIndex].conversations[convIndex]
        }
        save()
    }

    func getQueuedMessages(in conversation: Conversation, in project: Project) -> [ChatMessage] {
        guard let (projectIndex, convIndex) = findIndices(for: project, conversation: conversation) else { return [] }
        return projects[projectIndex].conversations[convIndex].messages.filter { $0.isQueued }
    }

    func clearQueuedFlags(in conversation: Conversation, in project: Project) {
        guard let (projectIndex, convIndex) = findIndices(for: project, conversation: conversation) else { return }
        for i in projects[projectIndex].conversations[convIndex].messages.indices {
            if projects[projectIndex].conversations[convIndex].messages[i].isQueued {
                projects[projectIndex].conversations[convIndex].messages[i].isQueued = false
            }
        }
        currentProject = projects[projectIndex]
        if currentConversation?.id == conversation.id {
            currentConversation = projects[projectIndex].conversations[convIndex]
        }
        save()
    }

    func replaceMessages(_ conversation: Conversation, in project: Project, with messages: [ChatMessage]) {
        guard let (projectIndex, convIndex) = findIndices(for: project, conversation: conversation) else { return }
        projects[projectIndex].conversations[convIndex].messages = messages
        if let lastTimestamp = messages.last?.timestamp {
            projects[projectIndex].conversations[convIndex].lastMessageAt = lastTimestamp
        }
        currentProject = projects[projectIndex]
        if currentConversation?.id == conversation.id {
            currentConversation = projects[projectIndex].conversations[convIndex]
        }
        save()
    }
}
