import UIKit

final class KeyboardDismissGesture: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissGesture()
    private var isInstalled = false
    private let exemptViews = NSHashTable<UIView>.weakObjects()

    func exempt(_ view: UIView) {
        exemptViews.add(view)
    }

    func install() {
        if isInstalled { return }
        let scene = UIApplication.shared.connectedScenes.first { $0 is UIWindowScene } as? UIWindowScene
        if let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first {
            let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
            isInstalled = true
        }
    }

    @objc private func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch
    ) -> Bool {
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView { return false }
            if current is UIControl { return false }
            view = current.superview
        }
        for exempt in exemptViews.allObjects where exempt.window === touch.window {
            if exempt.bounds.contains(touch.location(in: exempt)) { return false }
        }
        return true
    }
}
