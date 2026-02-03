//
//  ProjectStore.swift
//  Cloude

import Foundation
import Combine

import CloudeShared

struct PendingQuestion: Equatable {
    let conversationId: UUID
    let questions: [Question]
}

@MainActor
class ProjectStore: ObservableObject {
    @Published var projects: [Project] = []
    @Published var currentProject: Project?
    @Published var currentConversation: Conversation?
    @Published var pendingQuestion: PendingQuestion?
    @Published var questionInputFocused: Bool = false

    private let saveKey = "saved_projects"

    init() {
        load()
    }

    func findIndices(for project: Project, conversation: Conversation) -> (projectIndex: Int, convIndex: Int)? {
        guard let pIdx = projects.firstIndex(where: { $0.id == project.id }),
              let cIdx = projects[pIdx].conversations.firstIndex(where: { $0.id == conversation.id }) else {
            return nil
        }
        return (pIdx, cIdx)
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

    func save() {
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
