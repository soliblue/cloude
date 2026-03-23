// WhiteboardSheet+GestureHandlers.swift

import SwiftUI

extension WhiteboardSheet {
    enum DragIntent {
        case movingElement(id: String, startX: Double, startY: Double)
        case movingPath(id: String, startPoints: [[Double]])
        case movingGroup(startPositions: [(String, Double, Double, [[Double]]?)])
        case drawing(id: String)
        case sizingShape(id: String, startPoint: CGPoint)
    }

    func handleGestureTap(at point: CGPoint) {
        switch store.activeTool {
        case .hand:
            editingTextId = nil
            if let element = store.elementAt(point: point, canvasSize: canvasSize) {
                if element.groupId != nil {
                    store.selectGroup(of: element.id)
                } else {
                    store.clearSelection()
                    store.selectedElementIds = [element.id]
                }
            } else {
                store.clearSelection()
            }
        case .multiSelect:
            if let element = store.elementAt(point: point, canvasSize: canvasSize) {
                store.toggleSelection(element.id)
            } else {
                store.clearSelection()
                store.activeTool = .hand
            }
        case .rect, .ellipse, .triangle:
            let boardPoint = store.screenToBoard(point, canvasSize: canvasSize)
            _ = store.placeShape(at: boardPoint)
        case .text:
            let boardPoint = store.screenToBoard(point, canvasSize: canvasSize)
            let element = store.createText(at: boardPoint)
            store.selectedElementIds = [element.id]
            store.activeTool = .hand
            editingTextValue = ""
            editingTextId = element.id
        case .pencil:
            break
        case .arrow:
            if let element = store.elementAt(point: point, canvasSize: canvasSize) {
                if let sourceId = store.arrowSourceId {
                    if sourceId != element.id {
                        store.addArrow(from: sourceId, to: element.id)
                    }
                } else {
                    store.arrowSourceId = element.id
                    store.selectedElementIds = [element.id]
                }
            } else {
                store.arrowSourceId = nil
            }
        }
    }

    func handleGestureDoubleTap(at point: CGPoint) {
        if let element = store.elementAt(point: point, canvasSize: canvasSize) {
            store.selectedElementIds = [element.id]
            editingTextValue = element.label ?? ""
            editingTextId = element.id
        }
    }

    func handleGestureOneDrag(phase: WhiteboardGestureView.GesturePhase, start: CGPoint, current: CGPoint, translation: CGSize) {
        switch phase {
        case .began:
            switch store.activeTool {
            case .hand:
                if let element = store.elementAt(point: start, canvasSize: canvasSize) {
                    store.beginTransaction()
                    if element.groupId != nil {
                        store.selectGroup(of: element.id)
                        dragIntent = .movingGroup(startPositions: store.selectedIds.compactMap { id in
                            store.state.elements.first(where: { $0.id == id }).map { (id, $0.x, $0.y, $0.points) }
                        })
                    } else if element.type == .path {
                        dragIntent = .movingPath(id: element.id, startPoints: element.points ?? [])
                    } else {
                        dragIntent = .movingElement(id: element.id, startX: element.x, startY: element.y)
                    }
                    if element.groupId == nil {
                        store.clearSelection()
                        store.selectedElementIds = [element.id]
                    }
                }
            case .pencil:
                let boardPoint = store.screenToBoard(current, canvasSize: canvasSize)
                let id = store.beginPath(at: boardPoint)
                dragIntent = .drawing(id: id)
            case .rect, .ellipse, .triangle:
                let boardPoint = store.screenToBoard(start, canvasSize: canvasSize)
                let type: WhiteboardElementType = store.activeTool == .rect ? .rect : store.activeTool == .triangle ? .triangle : .ellipse
                let id = store.beginShape(type: type, at: boardPoint)
                dragIntent = .sizingShape(id: id, startPoint: boardPoint)
            case .multiSelect, .text, .arrow:
                break
            }
        case .changed:
            let s = store.scale(for: canvasSize)
            switch dragIntent {
            case .movingElement(let id, let startX, let startY):
                store.moveElementDirect(id: id, x: startX + translation.width / s, y: startY + translation.height / s)
            case .movingPath(let id, let startPoints):
                store.movePathDirect(id: id, startPoints: startPoints, dx: translation.width / s, dy: translation.height / s)
            case .movingGroup(let startPositions):
                let dx = translation.width / s
                let dy = translation.height / s
                for (id, startX, startY, startPoints) in startPositions {
                    if let startPoints {
                        store.movePathDirect(id: id, startPoints: startPoints, dx: dx, dy: dy)
                    } else {
                        store.moveElementDirect(id: id, x: startX + dx, y: startY + dy)
                    }
                }
            case .drawing(let id):
                let boardPoint = store.screenToBoard(current, canvasSize: canvasSize)
                store.appendPathPoint(id: id, point: [boardPoint.x, boardPoint.y])
            case .sizingShape(let id, let startPoint):
                let currentBoard = store.screenToBoard(current, canvasSize: canvasSize)
                let x = min(startPoint.x, currentBoard.x)
                let y = min(startPoint.y, currentBoard.y)
                let w = abs(currentBoard.x - startPoint.x)
                let h = abs(currentBoard.y - startPoint.y)
                store.resizeElementDirect(id: id, x: x, y: y, w: w, h: h)
            case .none:
                break
            }
        case .ended:
            if case .drawing(let id) = dragIntent {
                store.finalizePath(id: id)
            }
            if case .sizingShape = dragIntent {
                store.activeTool = .hand
            }
            store.commitTransaction()
            dragIntent = nil
        }
    }
    func handleGestureTwoPan(phase: WhiteboardGestureView.GesturePhase, translation: CGSize) {
        let s = store.scale(for: canvasSize)
        switch phase {
        case .began:
            store.beginTransaction()
            panStart = CGPoint(x: store.state.viewport.x, y: store.state.viewport.y)
        case .changed:
            if let start = panStart {
                store.panViewportDirect(x: start.x + translation.width / s, y: start.y + translation.height / s)
            }
        case .ended:
            panStart = nil
            store.commitTransaction()
        }
    }
    func handleGesturePinch(phase: WhiteboardGestureView.GesturePhase, scale: CGFloat) {
        switch phase {
        case .began:
            store.beginTransaction()
        case .changed:
            if let selectedId = store.selectedElementId, store.selectedIds.count == 1,
               let index = store.state.elements.firstIndex(where: { $0.id == selectedId }) {
                let el = store.state.elements[index]
                let centerX = el.x + el.w / 2
                let centerY = el.y + el.h / 2
                let newW = max(20, el.w * Double(scale))
                let newH = max(20, el.h * Double(scale))
                store.resizeElementDirect(id: selectedId, x: centerX - newW / 2, y: centerY - newH / 2, w: newW, h: newH)
            } else {
                store.zoomViewportDirect(zoom: store.state.viewport.zoom * scale)
            }
        case .ended:
            store.commitTransaction()
        }
    }
}
