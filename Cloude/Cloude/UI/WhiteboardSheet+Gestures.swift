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
            if let view = gesture.view {
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
        }

        @objc func handleTwoPan(_ gesture: UIPanGestureRecognizer) {
            if let view = gesture.view {
                let translation = gesture.translation(in: view)
                let phase: GesturePhase = gesture.state == .began ? .began : gesture.state == .changed ? .changed : .ended
                onTwoPan(phase, CGSize(width: translation.x, height: translation.y))
                if gesture.state == .ended || gesture.state == .cancelled {
                    gesture.setTranslation(.zero, in: view)
                }
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
        case movingPath(id: String, startPoints: [[Double]])
        case drawing(id: String)
        case sizingShape(id: String, startPoint: CGPoint)
    }

    func handleGestureTap(at point: CGPoint) {
        switch store.activeTool {
        case .hand:
            editingTextId = nil
            if let element = store.elementAt(point: point, canvasSize: canvasSize) {
                store.selectedElementId = element.id
            } else {
                store.selectedElementId = nil
            }
        case .rect, .ellipse:
            let boardPoint = store.screenToBoard(point, canvasSize: canvasSize)
            _ = store.placeShape(at: boardPoint)
        case .text:
            let boardPoint = store.screenToBoard(point, canvasSize: canvasSize)
            let element = store.createText(at: boardPoint)
            store.selectedElementId = element.id
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
                    store.selectedElementId = element.id
                }
            } else {
                store.arrowSourceId = nil
            }
        }
    }

    func handleGestureDoubleTap(at point: CGPoint) {
        if let element = store.elementAt(point: point, canvasSize: canvasSize) {
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
                if let element = store.elementAt(point: start, canvasSize: canvasSize) {
                    store.beginTransaction()
                    if element.type == .path {
                        dragIntent = .movingPath(id: element.id, startPoints: element.points ?? [])
                    } else {
                        dragIntent = .movingElement(id: element.id, startX: element.x, startY: element.y)
                    }
                    store.selectedElementId = element.id
                }
            case .pencil:
                let boardPoint = store.screenToBoard(current, canvasSize: canvasSize)
                let id = store.beginPath(at: boardPoint)
                dragIntent = .drawing(id: id)
            case .rect, .ellipse:
                let boardPoint = store.screenToBoard(start, canvasSize: canvasSize)
                let type: WhiteboardElementType = store.activeTool == .rect ? .rect : .ellipse
                let id = store.beginShape(type: type, at: boardPoint)
                dragIntent = .sizingShape(id: id, startPoint: boardPoint)
            case .text, .arrow:
                break
            }

        case .changed:
            let s = store.scale(for: canvasSize)
            switch dragIntent {
            case .movingElement(let id, let startX, let startY):
                store.moveElementDirect(id: id, x: startX + translation.width / s, y: startY + translation.height / s)
            case .movingPath(let id, let startPoints):
                store.movePathDirect(id: id, startPoints: startPoints, dx: translation.width / s, dy: translation.height / s)
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
        if phase == .began {
            store.beginTransaction()
        }
        if phase == .changed {
            if let selectedId = store.selectedElementId,
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
        }
        if phase == .ended {
            store.commitTransaction()
        }
    }
}
