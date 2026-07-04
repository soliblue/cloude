import UIKit

final class WindowsPagerGesture: NSObject, UIGestureRecognizerDelegate {
    static let shared = WindowsPagerGesture()

    private weak var window: UIWindow?
    private var pan: UIPanGestureRecognizer?
    private var keyboardVisible = false

    var canBeginLeft: (() -> Bool)?
    var canBeginRight: (() -> Bool)?
    var onChanged: ((UIRectEdge, CGFloat) -> Void)?
    var onFinished: ((UIRectEdge, CGFloat, CGFloat) -> Void)?

    override init() {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(
            forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.keyboardVisible = true
        }
        center.addObserver(
            forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.keyboardVisible = false
        }
    }

    func install() {
        let scene = UIApplication.shared.connectedScenes.first { $0 is UIWindowScene } as? UIWindowScene
        if let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first {
            if self.window !== window {
                uninstall()
                let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
                pan.maximumNumberOfTouches = 1
                pan.delegate = self
                window.addGestureRecognizer(pan)

                self.window = window
                self.pan = pan
            }
        }
    }

    func uninstall() {
        if let pan {
            pan.view?.removeGestureRecognizer(pan)
        }
        pan = nil
        window = nil
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: recognizer.view).x
        let velocity = recognizer.velocity(in: recognizer.view).x
        let edge: UIRectEdge = velocity >= 0 ? .left : .right
        if recognizer.state == .began || recognizer.state == .changed {
            onChanged?(edge, translation)
        } else if recognizer.state == .ended || recognizer.state == .cancelled || recognizer.state == .failed {
            onFinished?(edge, translation, velocity)
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if keyboardVisible {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            return false
        }
        if let recognizer = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = recognizer.velocity(in: recognizer.view)
            let isHorizontal = abs(velocity.x) > abs(velocity.y) * 1.25
            if !isHorizontal { return false }
            if velocity.x > 0 {
                return canBeginLeft?() ?? false
            }
            if velocity.x < 0 {
                return canBeginRight?() ?? false
            }
        }
        return false
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch
    ) -> Bool {
        var responder: UIResponder? = touch.view
        while let current = responder {
            if let controller = current as? UIViewController {
                if controller.presentingViewController != nil { return false }
                break
            }
            responder = current.next
        }
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView { return false }
            if current is UIControl { return false }
            if let scroll = current as? UIScrollView,
                scroll.contentSize.width > scroll.bounds.width + 1
            {
                return false
            }
            view = current.superview
        }
        return true
    }
}
