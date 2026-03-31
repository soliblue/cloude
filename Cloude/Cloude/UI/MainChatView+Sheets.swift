import SwiftUI
import UIKit

extension MainChatView {
    func keyboardAnimation(from notification: Notification) -> Animation {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curveRaw = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0
        if UIView.AnimationCurve(rawValue: Int(curveRaw)) == .easeInOut {
            return .easeInOut(duration: duration)
        }
        return .easeOut(duration: duration)
    }
}

struct PageSwipeDisabler: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.asyncAfter(deadline: .now() + DS.Delay.s) {
            guard let hostingView = view.findHostingParent() else { return }
            hostingView.disableHorizontalScrollViews()
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

extension UIView {
    func findHostingParent() -> UIView? {
        var current: UIView? = self
        while let parent = current?.superview {
            let typeName = String(describing: type(of: parent))
            if typeName.contains("UIHostingView") || typeName.contains("HostingView") {
                return parent
            }
            current = parent
        }
        return superview
    }

    func disableHorizontalScrollViews() {
        for subview in subviews {
            if let scrollView = subview as? UIScrollView,
               !scrollView.alwaysBounceVertical,
               scrollView.isPagingEnabled {
                scrollView.isScrollEnabled = false
            }
            subview.disableHorizontalScrollViews()
        }
    }
}
