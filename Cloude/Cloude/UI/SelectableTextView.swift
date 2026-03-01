import SwiftUI
import UIKit

struct SelectableTextView: UIViewRepresentable {
    let attributedString: NSAttributedString
    var onLinkTap: ((URL) -> Void)?
    var detectLinks: Bool = false

    func makeUIView(context: Context) -> SelectableUITextView {
        let textView = SelectableUITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        textView.linkTextAttributes = [:]
        if detectLinks {
            textView.dataDetectorTypes = .link
        }
        return textView
    }

    func updateUIView(_ textView: SelectableUITextView, context: Context) {
        if textView.attributedText != attributedString {
            textView.attributedText = attributedString
            textView.invalidateIntrinsicContentSize()
        }
        context.coordinator.onLinkTap = onLinkTap
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onLinkTap: onLinkTap)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onLinkTap: ((URL) -> Void)?

        init(onLinkTap: ((URL) -> Void)?) {
            self.onLinkTap = onLinkTap
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            if let tv = textView as? SelectableUITextView {
                tv.updateScrollLock()
            }
        }

        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
            if let onLinkTap {
                onLinkTap(URL)
                return false
            }
            return true
        }
    }
}

final class SelectableUITextView: UITextView {
    private static var activeTextView: SelectableUITextView?
    private var installedProxy = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        installProxyIfNeeded()
    }

    override func resignFirstResponder() -> Bool {
        if SelectableUITextView.activeTextView === self {
            SelectableUITextView.activeTextView = nil
        }
        return super.resignFirstResponder()
    }

    func updateScrollLock() {
        if selectedRange.length > 0 {
            SelectableUITextView.activeTextView = self
        } else if SelectableUITextView.activeTextView === self {
            SelectableUITextView.activeTextView = nil
        }
    }

    private func installProxyIfNeeded() {
        guard !installedProxy else { return }
        if let scroll = findAncestorScrollView() {
            let pan = scroll.panGestureRecognizer
            let proxy = ScrollPanDelegate(original: pan.delegate)
            pan.delegate = proxy
            objc_setAssociatedObject(scroll, &AssociatedKeys.proxyKey, proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            installedProxy = true
        }
    }

    private func findAncestorScrollView() -> UIScrollView? {
        var v = superview
        while let current = v {
            if let scroll = current as? UIScrollView, scroll !== self {
                return scroll
            }
            v = current.superview
        }
        return nil
    }

    static var hasActiveSelection: Bool {
        if let active = activeTextView {
            return active.isFirstResponder && active.selectedRange.length > 0
        }
        return false
    }
}

private struct AssociatedKeys {
    static var proxyKey = 0
}

private class ScrollPanDelegate: NSObject, UIGestureRecognizerDelegate {
    weak var original: UIGestureRecognizerDelegate?

    init(original: UIGestureRecognizerDelegate?) {
        self.original = original
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if SelectableUITextView.hasActiveSelection {
            return false
        }
        return original?.gestureRecognizerShouldBegin?(gestureRecognizer) ?? true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return original?.gestureRecognizer?(gestureRecognizer, shouldRecognizeSimultaneouslyWith: otherGestureRecognizer) ?? false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return original?.gestureRecognizer?(gestureRecognizer, shouldRequireFailureOf: otherGestureRecognizer) ?? false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return original?.gestureRecognizer?(gestureRecognizer, shouldBeRequiredToFailBy: otherGestureRecognizer) ?? false
    }

    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || (original?.responds(to: aSelector) ?? false)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if original?.responds(to: aSelector) == true { return original }
        return super.forwardingTarget(for: aSelector)
    }
}
