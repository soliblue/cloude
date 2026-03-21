// WhiteboardSheet+Gestures.swift

import SwiftUI
import UIKit

struct WhiteboardGestureView: UIViewRepresentable {
    var onTap: (CGPoint) -> Void
    var onDoubleTap: (CGPoint) -> Void
    var onOneDrag: (GesturePhase, CGPoint, CGPoint, CGSize) -> Void
    var onTwoPan: (GesturePhase, CGSize) -> Void
    var onPinch: (GesturePhase, CGFloat) -> Void

    enum GesturePhase {
        case began
        case changed
        case ended
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.require(toFail: doubleTap)
        view.addGestureRecognizer(tap)

        let oneFinger = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleOneDrag(_:)))
        oneFinger.minimumNumberOfTouches = 1
        oneFinger.maximumNumberOfTouches = 1
        view.addGestureRecognizer(oneFinger)

        let twoFinger = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTwoPan(_:)))
        twoFinger.minimumNumberOfTouches = 2
        twoFinger.maximumNumberOfTouches = 2
        view.addGestureRecognizer(twoFinger)

        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        view.addGestureRecognizer(pinch)

        oneFinger.delegate = context.coordinator
        twoFinger.delegate = context.coordinator
        pinch.delegate = context.coordinator

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.onDoubleTap = onDoubleTap
        context.coordinator.onOneDrag = onOneDrag
        context.coordinator.onTwoPan = onTwoPan
        context.coordinator.onPinch = onPinch
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap, onDoubleTap: onDoubleTap, onOneDrag: onOneDrag, onTwoPan: onTwoPan, onPinch: onPinch)
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTap: (CGPoint) -> Void
        var onDoubleTap: (CGPoint) -> Void
        var onOneDrag: (GesturePhase, CGPoint, CGPoint, CGSize) -> Void
        var onTwoPan: (GesturePhase, CGSize) -> Void
        var onPinch: (GesturePhase, CGFloat) -> Void
        private var dragStart: CGPoint = .zero

        init(onTap: @escaping (CGPoint) -> Void,
             onDoubleTap: @escaping (CGPoint) -> Void,
             onOneDrag: @escaping (GesturePhase, CGPoint, CGPoint, CGSize) -> Void,
             onTwoPan: @escaping (GesturePhase, CGSize) -> Void,
             onPinch: @escaping (GesturePhase, CGFloat) -> Void) {
            self.onTap = onTap
            self.onDoubleTap = onDoubleTap
            self.onOneDrag = onOneDrag
            self.onTwoPan = onTwoPan
            self.onPinch = onPinch
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            false
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            onTap(gesture.location(in: gesture.view))
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            onDoubleTap(gesture.location(in: gesture.view))
        }

        @objc func handleOneDrag(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }
            let location = gesture.location(in: view)
            let translation = gesture.translation(in: view)

            switch gesture.state {
            case .began:
                dragStart = location
                onOneDrag(.began, dragStart, location, CGSize(width: translation.x, height: translation.y))
            case .changed:
                onOneDrag(.changed, dragStart, location, CGSize(width: translation.x, height: translation.y))
            case .ended, .cancelled:
                onOneDrag(.ended, dragStart, location, CGSize(width: translation.x, height: translation.y))
            default:
                break
            }
        }

        @objc func handleTwoPan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }
            let translation = gesture.translation(in: view)
            let phase: GesturePhase = gesture.state == .began ? .began : gesture.state == .changed ? .changed : .ended
            onTwoPan(phase, CGSize(width: translation.x, height: translation.y))
            if gesture.state == .ended || gesture.state == .cancelled {
                gesture.setTranslation(.zero, in: view)
            }
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            let phase: GesturePhase = gesture.state == .began ? .began : gesture.state == .changed ? .changed : .ended
            onPinch(phase, gesture.scale)
            if gesture.state == .changed {
                gesture.scale = 1.0
            }
        }
    }
}

extension WhiteboardSheet {
    enum DragIntent {
        case movingElement(id: String, startX: Double, startY: Double)
        case drawing(id: String)
        case sizingShape(id: String, startPoint: CGPoint)
    }

    func handleGestureTap(at point: CGPoint) {
        switch store.activeTool {
        case .hand:
            editingTextId = nil
            if let element = store.elementAt(point: point, viewport: store.state.viewport, canvasSize: canvasSize) {
                store.selectedElementId = element.id
            } else {
                store.selectedElementId = nil
            }
        case .rect, .ellipse:
            let boardPoint = store.screenToBoard(point, viewport: store.state.viewport, canvasSize: canvasSize)
            store.placeShape(at: boardPoint)
        case .text:
            let boardPoint = store.screenToBoard(point, viewport: store.state.viewport, canvasSize: canvasSize)
            let element = WhiteboardElement(type: .text, x: boardPoint.x, y: boardPoint.y, label: "", stroke: store.activeColor)
            store.addElement(element)
            store.selectedElementId = element.id
            store.activeTool = .hand
            editingTextValue = ""
            editingTextId = element.id
        case .pencil:
            break
        case .arrow:
            if let element = store.elementAt(point: point, viewport: store.state.viewport, canvasSize: canvasSize) {
                if let sourceId = store.arrowSourceId {
                    if sourceId != element.id {
                        store.addArrow(from: sourceId, to: element.id)
                    }
                } else {
                    store.arrowSourceId = element.id
                    store.selectedElementId = element.id
                }
            } else {
                store.arrowSourceId = nil
            }
        }
    }

    func handleGestureDoubleTap(at point: CGPoint) {
        if let element = store.elementAt(point: point, viewport: store.state.viewport, canvasSize: canvasSize) {
            store.selectedElementId = element.id
            editingTextValue = element.label ?? ""
            editingTextId = element.id
        }
    }

    func handleGestureOneDrag(phase: WhiteboardGestureView.GesturePhase, start: CGPoint, current: CGPoint, translation: CGSize) {
        switch phase {
        case .began:
            switch store.activeTool {
            case .hand:
                if let element = store.elementAt(point: start, viewport: store.state.viewport, canvasSize: canvasSize) {
                    dragIntent = .movingElement(id: element.id, startX: element.x, startY: element.y)
                    store.selectedElementId = element.id
                }
            case .pencil:
                let boardPoint = store.screenToBoard(current, viewport: store.state.viewport, canvasSize: canvasSize)
                let element = WhiteboardElement(type: .path, stroke: store.activeColor, points: [[boardPoint.x, boardPoint.y]], closed: false)
                store.addElement(element)
                dragIntent = .drawing(id: element.id)
            case .rect, .ellipse:
                let boardPoint = store.screenToBoard(start, viewport: store.state.viewport, canvasSize: canvasSize)
                let element = WhiteboardElement(
                    type: store.activeTool == .rect ? .rect : .ellipse,
                    x: boardPoint.x, y: boardPoint.y, w: 1, h: 1,
                    fill: store.activeColor
                )
                store.addElement(element)
                dragIntent = .sizingShape(id: element.id, startPoint: boardPoint)
            case .text, .arrow:
                break
            }

        case .changed:
            let scale = canvasSize.width / 1000.0 * store.state.viewport.zoom
            switch dragIntent {
            case .movingElement(let id, let startX, let startY):
                if let index = store.state.elements.firstIndex(where: { $0.id == id }) {
                    store.state.elements[index].x = startX + translation.width / scale
                    store.state.elements[index].y = startY + translation.height / scale
                }
            case .drawing(let id):
                let boardPoint = store.screenToBoard(current, viewport: store.state.viewport, canvasSize: canvasSize)
                if let index = store.state.elements.firstIndex(where: { $0.id == id }),
                   let points = store.state.elements[index].points,
                   let last = points.last {
                    let dx = boardPoint.x - last[0]
                    let dy = boardPoint.y - last[1]
                    if dx * dx + dy * dy >= 4 {
                        store.state.elements[index].points?.append([boardPoint.x, boardPoint.y])
                    }
                }
            case .sizingShape(let id, let startPoint):
                let currentBoard = store.screenToBoard(current, viewport: store.state.viewport, canvasSize: canvasSize)
                if let index = store.state.elements.firstIndex(where: { $0.id == id }) {
                    let x = min(startPoint.x, currentBoard.x)
                    let y = min(startPoint.y, currentBoard.y)
                    let w = abs(currentBoard.x - startPoint.x)
                    let h = abs(currentBoard.y - startPoint.y)
                    store.state.elements[index].x = x
                    store.state.elements[index].y = y
                    store.state.elements[index].w = max(w, 5)
                    store.state.elements[index].h = max(h, 5)
                }
            case .none:
                break
            }

        case .ended:
            if case .drawing(let id) = dragIntent {
                if let index = store.state.elements.firstIndex(where: { $0.id == id }),
                   var points = store.state.elements[index].points {
                    points = simplifyPath(points, epsilon: 2.0)
                    store.state.elements[index].points = points
                }
            }
            if case .sizingShape = dragIntent {
                store.activeTool = .hand
            }
            dragIntent = nil
        }
    }

    func handleGestureTwoPan(phase: WhiteboardGestureView.GesturePhase, translation: CGSize) {
        let scale = canvasSize.width / 1000.0 * store.state.viewport.zoom
        switch phase {
        case .began:
            panStart = CGPoint(x: store.state.viewport.x, y: store.state.viewport.y)
        case .changed:
            if let start = panStart {
                store.state.viewport.x = start.x + translation.width / scale
                store.state.viewport.y = start.y + translation.height / scale
            }
        case .ended:
            panStart = nil
        }
    }

    func handleGesturePinch(phase: WhiteboardGestureView.GesturePhase, scale: CGFloat) {
        if phase == .changed {
            if let selectedId = store.selectedElementId,
               let index = store.state.elements.firstIndex(where: { $0.id == selectedId }) {
                let centerX = store.state.elements[index].x + store.state.elements[index].w / 2
                let centerY = store.state.elements[index].y + store.state.elements[index].h / 2
                let newW = max(20, store.state.elements[index].w * Double(scale))
                let newH = max(20, store.state.elements[index].h * Double(scale))
                store.state.elements[index].w = newW
                store.state.elements[index].h = newH
                store.state.elements[index].x = centerX - newW / 2
                store.state.elements[index].y = centerY - newH / 2
            } else {
                store.state.viewport.zoom = max(0.3, min(5.0, store.state.viewport.zoom * scale))
            }
        }
    }

    func simplifyPath(_ points: [[Double]], epsilon: Double) -> [[Double]] {
        guard points.count > 2 else { return points }
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
}
