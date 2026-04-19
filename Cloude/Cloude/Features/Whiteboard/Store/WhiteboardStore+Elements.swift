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
        selectedElementIds.remove(id)
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
        selectedElementIds.subtract(removeSet)
    }

    func updateElement(id: String, x: Double? = nil, y: Double? = nil, w: Double? = nil, h: Double? = nil, label: String? = nil, fill: String? = nil, stroke: String? = nil, points: [[Double]]? = nil, closed: Bool? = nil, from: String? = nil, to: String? = nil, type: WhiteboardElementType? = nil, z: Int? = nil, fontSize: Double? = nil, strokeWidth: Double? = nil, strokeStyle: String? = nil, opacity: Double? = nil, groupId: String? = nil) {
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
            if let z { el.z = z }
            if let fontSize { el.fontSize = fontSize }
            if let strokeWidth { el.strokeWidth = strokeWidth }
            if let strokeStyle { el.strokeStyle = strokeStyle }
            if let opacity { el.opacity = opacity }
            if let groupId { el.groupId = groupId }
        }
    }

    func recolorMany(ids: Set<String>, hex: String) {
        if ids.isEmpty { return }
        pushUndoSnapshot()
        for i in state.elements.indices {
            if ids.contains(state.elements[i].id) {
                if state.elements[i].type == .path || state.elements[i].type == .text {
                    state.elements[i].stroke = hex
                } else {
                    state.elements[i].fill = hex
                }
            }
        }
    }

    func moveForwardMany(ids: Set<String>) {
        if ids.isEmpty { return }
        pushUndoSnapshot()
        let indices = state.elements.indices.filter { ids.contains(state.elements[$0].id) }.sorted()
        for index in indices.reversed() {
            if index < state.elements.count - 1, !ids.contains(state.elements[index + 1].id) {
                state.elements.swapAt(index, index + 1)
            }
        }
    }

    func moveBackwardMany(ids: Set<String>) {
        if ids.isEmpty { return }
        pushUndoSnapshot()
        let indices = state.elements.indices.filter { ids.contains(state.elements[$0].id) }.sorted()
        for index in indices {
            if index > 0, !ids.contains(state.elements[index - 1].id) {
                state.elements.swapAt(index, index - 1)
            }
        }
    }

    func changeShape(id: String) {
        if let el = state.elements.first(where: { $0.id == id }) {
            let next: WhiteboardElementType? = {
                switch el.type {
                case .rect: return .ellipse
                case .ellipse: return .triangle
                case .triangle: return .rect
                default: return nil
                }
            }()
            if let next { mutateElement(id: id) { $0.type = next } }
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
                closed: element.closed,
                fontSize: element.fontSize, strokeWidth: element.strokeWidth,
                strokeStyle: element.strokeStyle, opacity: element.opacity
            )
            pushUndoSnapshot()
            state.elements.append(copy)
            selectedElementIds = [copy.id]
        }
    }

    func clear() {
        if !state.elements.isEmpty {
            pushUndoSnapshot()
            state.elements.removeAll()
            selectedElementIds.removeAll()
        }
    }
}
