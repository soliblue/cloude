// WhiteboardStore+Elements.swift

import Foundation

extension WhiteboardStore {
    func addElement(_ element: WhiteboardElement) {
        pushUndoSnapshot()
        state.elements.append(element)
    }

    func addElements(_ elements: [WhiteboardElement]) {
        if elements.isEmpty { return }
        pushUndoSnapshot()
        state.elements.append(contentsOf: elements)
    }

    func removeElement(id: String) {
        pushUndoSnapshot()
        let orphanedArrows = state.elements.filter { $0.type == .arrow && ($0.from == id || $0.to == id) }.map(\.id)
        state.elements.removeAll { $0.id == id || orphanedArrows.contains($0.id) }
        if selectedElementId == id {
            selectedElementId = nil
        }
    }

    func removeElements(ids: [String]) {
        if ids.isEmpty { return }
        pushUndoSnapshot()
        let idSet = Set(ids)
        let orphanedArrows = state.elements.filter { elem in
            guard elem.type == .arrow else { return false }
            if let from = elem.from, idSet.contains(from) { return true }
            if let to = elem.to, idSet.contains(to) { return true }
            return false
        }.map(\.id)
        let removeSet = idSet.union(orphanedArrows)
        state.elements.removeAll { removeSet.contains($0.id) }
        if let sel = selectedElementId, removeSet.contains(sel) {
            selectedElementId = nil
        }
    }

    func updateElement(id: String, x: Double? = nil, y: Double? = nil, w: Double? = nil, h: Double? = nil, label: String? = nil, fill: String? = nil, stroke: String? = nil, points: [[Double]]? = nil, closed: Bool? = nil, from: String? = nil, to: String? = nil, type: WhiteboardElementType? = nil) {
        mutateElement(id: id) { el in
            if let x { el.x = x }
            if let y { el.y = y }
            if let w { el.w = w }
            if let h { el.h = h }
            if let label { el.label = label }
            if let fill { el.fill = fill }
            if let stroke { el.stroke = stroke }
            if let points { el.points = points }
            if let closed { el.closed = closed }
            if let from { el.from = from }
            if let to { el.to = to }
            if let type { el.type = type }
        }
    }

    func updateLabel(id: String, label: String?) {
        mutateElement(id: id) { $0.label = label }
    }

    func recolor(id: String, fill: String?, stroke: String?) {
        mutateElement(id: id) { el in
            if let fill { el.fill = fill }
            if let stroke { el.stroke = stroke }
        }
    }

    func changeShape(id: String) {
        if let el = state.elements.first(where: { $0.id == id }) {
            if el.type == .rect || el.type == .ellipse {
                mutateElement(id: id) { $0.type = el.type == .rect ? .ellipse : .rect }
            }
        }
    }

    func canMoveForward(id: String) -> Bool {
        if let index = state.elements.firstIndex(where: { $0.id == id }) {
            return index < state.elements.count - 1
        }
        return false
    }

    func canMoveBackward(id: String) -> Bool {
        if let index = state.elements.firstIndex(where: { $0.id == id }) {
            return index > 0
        }
        return false
    }

    func moveForward(id: String) {
        if let index = state.elements.firstIndex(where: { $0.id == id }),
           index < state.elements.count - 1 {
            pushUndoSnapshot()
            state.elements.swapAt(index, index + 1)
        }
    }

    func moveBackward(id: String) {
        if let index = state.elements.firstIndex(where: { $0.id == id }),
           index > 0 {
            pushUndoSnapshot()
            state.elements.swapAt(index, index - 1)
        }
    }

    func duplicate(id: String) {
        if let element = state.elements.first(where: { $0.id == id }) {
            let copy = WhiteboardElement(
                type: element.type,
                x: element.x + 20, y: element.y + 20,
                w: element.w, h: element.h,
                label: element.label, fill: element.fill, stroke: element.stroke,
                points: element.points?.map { [$0[0] + 20, $0[1] + 20] },
                closed: element.closed
            )
            pushUndoSnapshot()
            state.elements.append(copy)
            selectedElementId = copy.id
        }
    }

    func clear() {
        if !state.elements.isEmpty {
            pushUndoSnapshot()
            state.elements.removeAll()
            selectedElementId = nil
        }
    }
}
