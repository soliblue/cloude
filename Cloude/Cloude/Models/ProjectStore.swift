//
//  ProjectStore.swift
//  Cloude
//
//  Project persistence and state management
//

import Foundation
import Combine

@MainActor
class ProjectStore: ObservableObject {
    @Published var projects: [Project] = []
    @Published var currentProject: Project?
    @Published var currentConversation: Conversation?

    private let saveKey = "saved_projects"

    init() {
        load()
    }

    func createProject(name: String, rootDirectory: String = "") -> Project {
        let project = Project(name: name, rootDirectory: rootDirectory)
        projects.insert(project, at: 0)
        currentProject = project
        save()
        return project
    }

    func selectProject(_ project: Project) {
        currentProject = project
        currentConversation = project.conversations.first
    }

    func selectConversation(_ conversation: Conversation, in project: Project) {
        currentProject = project
        currentConversation = conversation
    }

    func newConversation(in project: Project) -> Conversation {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else {
            return Conversation()
        }
        let conversation = Conversation()
        projects[index].addConversation(conversation)
        currentProject = projects[index]
        currentConversation = conversation
        save()
        return conversation
    }

    func addMessage(_ message: ChatMessage, to conversation: Conversation, in project: Project) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == project.id }),
              let convIndex = projects[projectIndex].conversations.firstIndex(where: { $0.id == conversation.id }) else {
            return
        }

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

    func updateSessionId(_ conversation: Conversation, in project: Project, sessionId: String) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == project.id }),
              let convIndex = projects[projectIndex].conversations.firstIndex(where: { $0.id == conversation.id }) else {
            return
        }
        projects[projectIndex].conversations[convIndex].sessionId = sessionId
        currentProject = projects[projectIndex]
        if currentConversation?.id == conversation.id {
            currentConversation = projects[projectIndex].conversations[convIndex]
        }
        save()
    }

    func renameProject(_ project: Project, to name: String) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index].name = name
        if currentProject?.id == project.id {
            currentProject = projects[index]
        }
        save()
    }

    func updateRootDirectory(_ project: Project, to path: String) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index].rootDirectory = path
        if currentProject?.id == project.id {
            currentProject = projects[index]
        }
        save()
    }

    func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        if currentProject?.id == project.id {
            currentProject = projects.first
            currentConversation = currentProject?.conversations.first
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

    private func save() {
        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Project].self, from: data) {
            projects = decoded
            currentProject = projects.first
            currentConversation = currentProject?.conversations.first
        }
    }
}
