//
//  PaneManager.swift
//  Cloude
//
//  Manages multiple chat pane state
//

import Foundation
import Combine

struct ChatPane: Identifiable {
    let id: UUID
    var conversationId: UUID?
    var projectId: UUID?

    init(id: UUID = UUID(), conversationId: UUID? = nil, projectId: UUID? = nil) {
        self.id = id
        self.conversationId = conversationId
        self.projectId = projectId
    }
}

@MainActor
class PaneManager: ObservableObject {
    @Published var panes: [ChatPane] = [ChatPane()]
    @Published var activePaneId: UUID?

    init() {
        activePaneId = panes.first?.id
    }

    var activePane: ChatPane? {
        panes.first { $0.id == activePaneId }
    }

    var canAddPane: Bool {
        panes.count < 4
    }

    var canRemovePane: Bool {
        panes.count > 1
    }

    func addPane() {
        guard canAddPane else { return }
        let pane = ChatPane()
        panes.append(pane)
        activePaneId = pane.id
    }

    func removePane(_ id: UUID) {
        guard canRemovePane else { return }
        panes.removeAll { $0.id == id }
        if activePaneId == id {
            activePaneId = panes.first?.id
        }
    }

    func setActive(_ id: UUID) {
        guard panes.contains(where: { $0.id == id }) else { return }
        activePaneId = id
    }

    func updatePane(_ id: UUID, conversationId: UUID?, projectId: UUID?) {
        guard let index = panes.firstIndex(where: { $0.id == id }) else { return }
        panes[index].conversationId = conversationId
        panes[index].projectId = projectId
    }

    func linkToCurrentConversation(_ paneId: UUID, project: Project?, conversation: Conversation?) {
        updatePane(paneId, conversationId: conversation?.id, projectId: project?.id)
    }
}
