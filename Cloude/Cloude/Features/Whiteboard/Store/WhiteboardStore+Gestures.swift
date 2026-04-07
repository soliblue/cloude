import Foundation
import SwiftUI

extension WhiteboardStore {
    func moveElementDirect(id: String, x: Double, y: Double) {
        if let index = state.elements.firstIndex(where: { $0.id == id }) {
            state.elements[index].x = x
            state.elements[index].y = y
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

    func placeShape(at boardPoint: CGPoint) -> WhiteboardElement? {
        let element: WhiteboardElement
        switch activeTool {
        case .rect:
            element = WhiteboardElement(type: .rect, x: boardPoint.x - 60, y: boardPoint.y - 35, w: 120, h: 70, fill: activeColor)
        case .ellipse:
            element = WhiteboardElement(type: .ellipse, x: boardPoint.x - 45, y: boardPoint.y - 45, w: 90, h: 90, fill: activeColor)
        case .triangle:
            element = WhiteboardElement(type: .triangle, x: boardPoint.x - 50, y: boardPoint.y - 43, w: 100, h: 86, fill: activeColor)
        default:
            return nil
        }
        addElement(element)
        selectedElementIds = [element.id]
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
}
