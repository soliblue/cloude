// WhiteboardStore+Groups.swift

import Foundation

extension WhiteboardStore {
    var selectedIds: Set<String> { selectedElementIds }

    func selectGroup(of elementId: String) {
        if let element = state.elements.first(where: { $0.id == elementId }),
           let groupId = element.groupId {
            selectedElementIds = Set(state.elements.filter { $0.groupId == groupId }.map(\.id))
        }
    }

    func toggleSelection(_ elementId: String) {
        if selectedElementIds.contains(elementId) {
            selectedElementIds.remove(elementId)
        } else {
            selectedElementIds.insert(elementId)
        }
    }

    func clearSelection() {
        selectedElementIds.removeAll()
    }

    func groupSelected() {
        let ids = selectedIds
        if ids.count < 2 { return }
        pushUndoSnapshot()
        let groupId = UUID().uuidString.prefix(8).lowercased()
        for i in state.elements.indices {
            if ids.contains(state.elements[i].id) {
                state.elements[i].groupId = String(groupId)
            }
        }
    }

    func ungroupSelected() {
        let ids = selectedIds
        if ids.isEmpty { return }
        let groupIds = Set(ids.compactMap { id in state.elements.first(where: { $0.id == id })?.groupId })
        if groupIds.isEmpty { return }
        pushUndoSnapshot()
        for i in state.elements.indices {
            if let gid = state.elements[i].groupId, groupIds.contains(gid) {
                state.elements[i].groupId = nil
            }
        }
        selectedElementIds.removeAll()
    }

    func moveGroup(dx: Double, dy: Double) {
        let ids = selectedIds
        for i in state.elements.indices {
            if ids.contains(state.elements[i].id) {
                if state.elements[i].type == .path {
                    state.elements[i].points = state.elements[i].points?.map { [$0[0] + dx, $0[1] + dy] }
                } else {
                    state.elements[i].x += dx
                    state.elements[i].y += dy
                }
            }
        }
    }

    func hasGroup(in ids: Set<String>) -> Bool {
        ids.compactMap { id in state.elements.first(where: { $0.id == id })?.groupId }.first != nil
    }
}
