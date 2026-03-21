// WhiteboardStore.swift

import Foundation
import SwiftUI
import Combine

@MainActor
class WhiteboardStore: ObservableObject {
    @Published var state = WhiteboardState()
    @Published var selectedElementId: String?
    @Published var activeTool: ActiveTool = .hand
    @Published var activeColor: String = "#FFFFFF"

    @Published var arrowSourceId: String?

    enum ActiveTool {
        case hand
        case rect
        case ellipse
        case text
        case pencil
        case arrow
    }

    private var undoStack: [[WhiteboardElement]] = []
    private var redoStack: [[WhiteboardElement]] = []
    private let maxUndoLevels = 50
    private var saveDebounce: Task<Void, Never>?
    private var currentConversationId: UUID?

    private static var storageDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("whiteboards")
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

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

    private func pushUndo() {
        undoStack.append(state.elements)
        if undoStack.count > maxUndoLevels {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        scheduleSave()
    }

    func undo() {
        if let previous = undoStack.popLast() {
            redoStack.append(state.elements)
            state.elements = previous
            selectedElementId = nil
            scheduleSave()
        }
    }

    func redo() {
        if let next = redoStack.popLast() {
            undoStack.append(state.elements)
            state.elements = next
            selectedElementId = nil
            scheduleSave()
        }
    }

    func addElement(_ element: WhiteboardElement) {
        pushUndo()
        state.elements.append(element)
    }

    func addElements(_ elements: [WhiteboardElement]) {
        if elements.isEmpty { return }
        pushUndo()
        state.elements.append(contentsOf: elements)
    }

    func removeElement(id: String) {
        pushUndo()
        state.elements.removeAll { $0.id == id }
        if selectedElementId == id {
            selectedElementId = nil
        }
    }

    func removeElements(ids: [String]) {
        if ids.isEmpty { return }
        pushUndo()
        let idSet = Set(ids)
        state.elements.removeAll { idSet.contains($0.id) }
        if let sel = selectedElementId, idSet.contains(sel) {
            selectedElementId = nil
        }
    }

    func updateElement(id: String, x: Double? = nil, y: Double? = nil, w: Double? = nil, h: Double? = nil, label: String? = nil, fill: String? = nil, stroke: String? = nil) {
        if let index = state.elements.firstIndex(where: { $0.id == id }) {
            pushUndo()
            if let x { state.elements[index].x = x }
            if let y { state.elements[index].y = y }
            if let w { state.elements[index].w = w }
            if let h { state.elements[index].h = h }
            if let label { state.elements[index].label = label }
            if let fill { state.elements[index].fill = fill }
            if let stroke { state.elements[index].stroke = stroke }
        }
    }

    func updateLabel(id: String, label: String?) {
        if let index = state.elements.firstIndex(where: { $0.id == id }) {
            pushUndo()
            state.elements[index].label = label
        }
    }

    func moveForward(id: String) {
        if let index = state.elements.firstIndex(where: { $0.id == id }),
           index < state.elements.count - 1 {
            pushUndo()
            state.elements.swapAt(index, index + 1)
        }
    }

    func moveBackward(id: String) {
        if let index = state.elements.firstIndex(where: { $0.id == id }),
           index > 0 {
            pushUndo()
            state.elements.swapAt(index, index - 1)
        }
    }

    func recolor(id: String, fill: String?, stroke: String?) {
        if let index = state.elements.firstIndex(where: { $0.id == id }) {
            pushUndo()
            if let fill { state.elements[index].fill = fill }
            if let stroke { state.elements[index].stroke = stroke }
        }
    }

    func changeShape(id: String) {
        if let index = state.elements.firstIndex(where: { $0.id == id }) {
            let el = state.elements[index]
            let nextType: WhiteboardElementType = el.type == .rect ? .ellipse : .rect
            if el.type == .rect || el.type == .ellipse {
                pushUndo()
                state.elements[index].type = nextType
            }
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
            pushUndo()
            state.elements.append(copy)
            selectedElementId = copy.id
        }
    }

    func clear() {
        if !state.elements.isEmpty {
            pushUndo()
            state.elements.removeAll()
            selectedElementId = nil
        }
    }

    func placeShape(at boardPoint: CGPoint) {
        let element: WhiteboardElement
        switch activeTool {
        case .rect:
            element = WhiteboardElement(type: .rect, x: boardPoint.x - 60, y: boardPoint.y - 35, w: 120, h: 70, fill: activeColor)
        case .ellipse:
            element = WhiteboardElement(type: .ellipse, x: boardPoint.x - 45, y: boardPoint.y - 45, w: 90, h: 90, fill: activeColor)
        default:
            return
        }
        addElement(element)
        selectedElementId = element.id
        activeTool = .hand
    }

    func elementAt(point: CGPoint, viewport: WhiteboardViewport, canvasSize: CGSize) -> WhiteboardElement? {
        let boardPoint = screenToBoard(point, viewport: viewport, canvasSize: canvasSize)
        return state.elements.last { element in
            switch element.type {
            case .rect, .ellipse, .text:
                return boardPoint.x >= element.x &&
                       boardPoint.x <= element.x + element.w &&
                       boardPoint.y >= element.y &&
                       boardPoint.y <= element.y + element.h
            case .path:
                if let points = element.points {
                    return points.contains { p in
                        let dx = boardPoint.x - p[0]
                        let dy = boardPoint.y - p[1]
                        return dx * dx + dy * dy < 225
                    }
                }
                return false
            case .arrow:
                return false
            }
        }
    }

    func screenToBoard(_ point: CGPoint, viewport: WhiteboardViewport, canvasSize: CGSize) -> CGPoint {
        let scale = canvasSize.width / 1000.0 * viewport.zoom
        return CGPoint(
            x: (point.x - canvasSize.width / 2) / scale + 500 - viewport.x,
            y: (point.y - canvasSize.height / 2) / scale + 500 - viewport.y
        )
    }

    func boardToScreen(_ point: CGPoint, viewport: WhiteboardViewport, canvasSize: CGSize) -> CGPoint {
        let scale = canvasSize.width / 1000.0 * viewport.zoom
        return CGPoint(
            x: (point.x - 500 + viewport.x) * scale + canvasSize.width / 2,
            y: (point.y - 500 + viewport.y) * scale + canvasSize.height / 2
        )
    }

    func addArrow(from fromId: String, to toId: String) {
        let arrow = WhiteboardElement(type: .arrow, from: fromId, to: toId)
        addElement(arrow)
        arrowSourceId = nil
        activeTool = .hand
    }

    func load(conversationId: UUID?) {
        currentConversationId = conversationId
        if let convId = conversationId {
            let url = Self.storageDir.appendingPathComponent("\(convId.uuidString).json")
            if let data = try? Data(contentsOf: url),
               let loaded = try? JSONDecoder().decode(WhiteboardState.self, from: data) {
                state = loaded
                undoStack.removeAll()
                redoStack.removeAll()
                selectedElementId = nil
                return
            }
        }
        state = WhiteboardState()
        undoStack.removeAll()
        redoStack.removeAll()
        selectedElementId = nil
    }

    func scheduleSave() {
        saveDebounce?.cancel()
        saveDebounce = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            if !Task.isCancelled { save() }
        }
    }

    private func save() {
        if let convId = currentConversationId {
            let dir = Self.storageDir
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if let data = try? JSONEncoder().encode(state) {
                try? data.write(to: dir.appendingPathComponent("\(convId.uuidString).json"))
            }
        }
    }
}
