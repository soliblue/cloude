//
//  PaneManager.swift
//  Cloude
//
//  Manages multiple chat pane state
//

import Foundation
import Combine

enum PaneType: String, CaseIterable, Codable {
    case chat
    case files
    case gitChanges

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .files: return "folder"
        case .gitChanges: return "arrow.triangle.branch"
        }
    }

    var label: String {
        switch self {
        case .chat: return "Chat"
        case .files: return "Files"
        case .gitChanges: return "Changes"
        }
    }
}

struct ChatPane: Identifiable, Codable {
    let id: UUID
    var type: PaneType
    var conversationId: UUID?
    var projectId: UUID?

    init(id: UUID = UUID(), type: PaneType = .chat, conversationId: UUID? = nil, projectId: UUID? = nil) {
        self.id = id
        self.type = type
        self.conversationId = conversationId
        self.projectId = projectId
    }
}

@MainActor
class PaneManager: ObservableObject {
    @Published var panes: [ChatPane] = [ChatPane()]
    @Published var activePaneId: UUID?
    @Published var focusModeEnabled: Bool = true {
        didSet { UserDefaults.standard.set(focusModeEnabled, forKey: focusModeKey) }
    }

    private let panesKey = "paneManager_panes"
    private let activeKey = "paneManager_activePaneId"
    private let focusModeKey = "paneManager_focusMode"

    init() {
        focusModeEnabled = UserDefaults.standard.object(forKey: focusModeKey) as? Bool ?? true
        load()
        if panes.isEmpty {
            panes = [ChatPane()]
        }
        if activePaneId == nil {
            activePaneId = panes.first?.id
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(panes) {
            UserDefaults.standard.set(data, forKey: panesKey)
        }
        if let activeId = activePaneId {
            UserDefaults.standard.set(activeId.uuidString, forKey: activeKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: panesKey),
           let decoded = try? JSONDecoder().decode([ChatPane].self, from: data) {
            panes = decoded
        }
        if let idString = UserDefaults.standard.string(forKey: activeKey),
           let id = UUID(uuidString: idString),
           panes.contains(where: { $0.id == id }) {
            activePaneId = id
        }
    }

    var activePane: ChatPane? {
        panes.first { $0.id == activePaneId }
    }

    var canAddPane: Bool {
        panes.count < 3
    }

    var canRemovePane: Bool {
        panes.count > 1
    }

    @discardableResult
    func addPane() -> UUID {
        let pane = ChatPane()
        guard canAddPane else { return pane.id }
        panes.append(pane)
        activePaneId = pane.id
        save()
        return pane.id
    }

    func removePane(_ id: UUID) {
        guard canRemovePane else { return }
        panes.removeAll { $0.id == id }
        if activePaneId == id {
            activePaneId = panes.first?.id
        }
        save()
    }

    func setActive(_ id: UUID) {
        guard panes.contains(where: { $0.id == id }) else { return }
        activePaneId = id
        save()
    }

    func updatePane(_ id: UUID, conversationId: UUID?, projectId: UUID?) {
        guard let index = panes.firstIndex(where: { $0.id == id }) else { return }
        panes[index].conversationId = conversationId
        panes[index].projectId = projectId
        save()
    }

    func linkToCurrentConversation(_ paneId: UUID, project: Project?, conversation: Conversation?) {
        updatePane(paneId, conversationId: conversation?.id, projectId: project?.id)
    }

    func setPaneType(_ paneId: UUID, type: PaneType) {
        guard let index = panes.firstIndex(where: { $0.id == paneId }) else { return }
        panes[index].type = type
        save()
    }
}
