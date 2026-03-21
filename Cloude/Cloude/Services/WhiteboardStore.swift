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
    private var inTransaction = false

    private static var storageDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("whiteboards")
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func scale(for canvasSize: CGSize) -> CGFloat {
        canvasSize.width / 1000.0 * state.viewport.zoom
    }

    // MARK: - Transactions

    func beginTransaction() {
        if !inTransaction {
            undoStack.append(state.elements)
            if undoStack.count > maxUndoLevels {
                undoStack.removeFirst()
            }
            redoStack.removeAll()
            inTransaction = true
        }
    }

    func commitTransaction() {
        inTransaction = false
        scheduleSave()
    }

    private func pushUndo() {
        if inTransaction { return }
        undoStack.append(state.elements)
        if undoStack.count > maxUndoLevels {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        scheduleSave()
    }

    private func mutateElement(id: String, _ mutation: (inout WhiteboardElement) -> Void) {
        if let index = state.elements.firstIndex(where: { $0.id == id }) {
            pushUndo()
            mutation(&state.elements[index])
        }
    }

    // MARK: - Undo/Redo

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

    // MARK: - Element CRUD

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
        let orphanedArrows = state.elements.filter { $0.type == .arrow && ($0.from == id || $0.to == id) }.map(\.id)
        state.elements.removeAll { $0.id == id || orphanedArrows.contains($0.id) }
        if selectedElementId == id {
            selectedElementId = nil
        }
    }

    func removeElements(ids: [String]) {
        if ids.isEmpty { return }
        pushUndo()
        let idSet = Set(ids)
        let orphanedArrows = state.elements.filter { $0.type == .arrow && ($0.from != nil && idSet.contains($0.from!) || $0.to != nil && idSet.contains($0.to!)) }.map(\.id)
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

    // MARK: - Layer Ordering

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

    // MARK: - Gesture Mutations (called during drag, use transactions)

    func moveElementDirect(id: String, x: Double, y: Double) {
        if let index = state.elements.firstIndex(where: { $0.id == id }) {
            state.elements[index].x = x
            state.elements[index].y = y
            if state.elements[index].type == .path {
                // no-op for path position - points are absolute
            }
        }
    }

    func movePathDirect(id: String, startPoints: [[Double]], dx: Double, dy: Double) {
        if let index = state.elements.firstIndex(where: { $0.id == id }) {
            state.elements[index].points = startPoints.map { [$0[0] + dx, $0[1] + dy] }
        }
    }

    func resizeElementDirect(id: String, x: Double, y: Double, w: Double, h: Double) {
        if let index = state.elements.firstIndex(where: { $0.id == id }) {
            state.elements[index].x = x
            state.elements[index].y = y
            state.elements[index].w = max(w, 5)
            state.elements[index].h = max(h, 5)
        }
    }

    func appendPathPoint(id: String, point: [Double]) {
        if let index = state.elements.firstIndex(where: { $0.id == id }),
           let points = state.elements[index].points,
           let last = points.last {
            let dx = point[0] - last[0]
            let dy = point[1] - last[1]
            if dx * dx + dy * dy >= 4 {
                state.elements[index].points?.append(point)
            }
        }
    }

    func finalizePath(id: String) {
        if let index = state.elements.firstIndex(where: { $0.id == id }),
           var points = state.elements[index].points {
            points = simplifyPath(points, epsilon: 2.0)
            state.elements[index].points = points
        }
    }

    func panViewportDirect(x: Double, y: Double) {
        state.viewport.x = x
        state.viewport.y = y
    }

    func zoomViewportDirect(zoom: Double) {
        state.viewport.zoom = max(0.3, min(5.0, zoom))
    }

    // MARK: - Element Factories

    func placeShape(at boardPoint: CGPoint) -> WhiteboardElement? {
        let element: WhiteboardElement
        switch activeTool {
        case .rect:
            element = WhiteboardElement(type: .rect, x: boardPoint.x - 60, y: boardPoint.y - 35, w: 120, h: 70, fill: activeColor)
        case .ellipse:
            element = WhiteboardElement(type: .ellipse, x: boardPoint.x - 45, y: boardPoint.y - 45, w: 90, h: 90, fill: activeColor)
        default:
            return nil
        }
        addElement(element)
        selectedElementId = element.id
        activeTool = .hand
        return element
    }

    func beginShape(type: WhiteboardElementType, at boardPoint: CGPoint) -> String {
        let element = WhiteboardElement(type: type, x: boardPoint.x, y: boardPoint.y, w: 1, h: 1, fill: activeColor)
        beginTransaction()
        state.elements.append(element)
        return element.id
    }

    func beginPath(at boardPoint: CGPoint) -> String {
        let element = WhiteboardElement(type: .path, stroke: activeColor, points: [[boardPoint.x, boardPoint.y]], closed: false)
        beginTransaction()
        state.elements.append(element)
        return element.id
    }

    func createText(at boardPoint: CGPoint) -> WhiteboardElement {
        let element = WhiteboardElement(type: .text, x: boardPoint.x, y: boardPoint.y, w: 10, h: 16, label: "", stroke: activeColor)
        addElement(element)
        return element
    }

    func addArrow(from fromId: String, to toId: String) {
        let arrow = WhiteboardElement(type: .arrow, from: fromId, to: toId)
        addElement(arrow)
        arrowSourceId = nil
        activeTool = .hand
    }

    // MARK: - Hit Testing

    func elementAt(point: CGPoint, canvasSize: CGSize) -> WhiteboardElement? {
        let boardPoint = screenToBoard(point, canvasSize: canvasSize)
        return state.elements.last { element in
            switch element.type {
            case .rect, .text:
                return boardPoint.x >= element.x &&
                       boardPoint.x <= element.x + element.w &&
                       boardPoint.y >= element.y &&
                       boardPoint.y <= element.y + element.h
            case .ellipse:
                let cx = element.x + element.w / 2
                let cy = element.y + element.h / 2
                let rx = element.w / 2
                let ry = element.h / 2
                if rx <= 0 || ry <= 0 { return false }
                let nx = (boardPoint.x - cx) / rx
                let ny = (boardPoint.y - cy) / ry
                return nx * nx + ny * ny <= 1
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
                if let fromId = element.from, let toId = element.to,
                   let fromEl = state.elements.first(where: { $0.id == fromId }),
                   let toEl = state.elements.first(where: { $0.id == toId }) {
                    let a = CGPoint(x: fromEl.x + fromEl.w / 2, y: fromEl.y + fromEl.h / 2)
                    let b = CGPoint(x: toEl.x + toEl.w / 2, y: toEl.y + toEl.h / 2)
                    return distanceToSegment(boardPoint, a: a, b: b) < 10
                }
                return false
            }
        }
    }

    private func distanceToSegment(_ p: CGPoint, a: CGPoint, b: CGPoint) -> Double {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lenSq = dx * dx + dy * dy
        if lenSq == 0 { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lenSq))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }

    // MARK: - Coordinate Transforms

    func screenToBoard(_ point: CGPoint, canvasSize: CGSize) -> CGPoint {
        let s = scale(for: canvasSize)
        return CGPoint(
            x: (point.x - canvasSize.width / 2) / s + 500 - state.viewport.x,
            y: (point.y - canvasSize.height / 2) / s + 500 - state.viewport.y
        )
    }

    func boardToScreen(_ point: CGPoint, canvasSize: CGSize) -> CGPoint {
        let s = scale(for: canvasSize)
        return CGPoint(
            x: (point.x - 500 + state.viewport.x) * s + canvasSize.width / 2,
            y: (point.y - 500 + state.viewport.y) * s + canvasSize.height / 2
        )
    }

    func screenFrame(for element: WhiteboardElement, canvasSize: CGSize) -> (position: CGPoint, width: CGFloat, height: CGFloat) {
        let screenPos = boardToScreen(CGPoint(x: element.x, y: element.y), canvasSize: canvasSize)
        let s = scale(for: canvasSize)
        return (screenPos, element.w * s, element.h * s)
    }

    // MARK: - Path Simplification (Ramer-Douglas-Peucker)

    private func simplifyPath(_ points: [[Double]], epsilon: Double) -> [[Double]] {
        if points.count <= 2 { return points }
        var maxDist = 0.0
        var maxIndex = 0
        let first = points[0]
        let last = points[points.count - 1]

        for i in 1..<(points.count - 1) {
            let dist = perpendicularDistance(point: points[i], lineStart: first, lineEnd: last)
            if dist > maxDist {
                maxDist = dist
                maxIndex = i
            }
        }

        if maxDist > epsilon {
            let left = simplifyPath(Array(points[0...maxIndex]), epsilon: epsilon)
            let right = simplifyPath(Array(points[maxIndex..<points.count]), epsilon: epsilon)
            return left.dropLast() + right
        }
        return [first, last]
    }

    private func perpendicularDistance(point: [Double], lineStart: [Double], lineEnd: [Double]) -> Double {
        let dx = lineEnd[0] - lineStart[0]
        let dy = lineEnd[1] - lineStart[1]
        let lineLenSq = dx * dx + dy * dy
        if lineLenSq == 0 {
            let ex = point[0] - lineStart[0]
            let ey = point[1] - lineStart[1]
            return sqrt(ex * ex + ey * ey)
        }
        return abs(dy * point[0] - dx * point[1] + lineEnd[0] * lineStart[1] - lineEnd[1] * lineStart[0]) / sqrt(lineLenSq)
    }

    // MARK: - Persistence

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
