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
