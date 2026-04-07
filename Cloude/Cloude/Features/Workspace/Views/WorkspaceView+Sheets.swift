import SwiftUI
import UIKit

extension WorkspaceView {
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
