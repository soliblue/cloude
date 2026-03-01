import SwiftUI
import UIKit

struct SelectableTextView: UIViewRepresentable {
    let attributedString: NSAttributedString
    var onLinkTap: ((URL) -> Void)?

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
        return textView
    }

    func updateUIView(_ textView: SelectableUITextView, context: Context) {
        textView.attributedText = attributedString
        context.coordinator.onLinkTap = onLinkTap
        textView.invalidateIntrinsicContentSize()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onLinkTap: onLinkTap)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var onLinkTap: ((URL) -> Void)?

        init(onLinkTap: ((URL) -> Void)?) {
            self.onLinkTap = onLinkTap
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            if let selectableTV = textView as? SelectableUITextView {
                let hasSelection = textView.selectedRange.length > 0
                selectableTV.setParentScrollEnabled(!hasSelection)
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

class SelectableUITextView: UITextView {
    func setParentScrollEnabled(_ enabled: Bool) {
        var view: UIView? = superview
        while let current = view {
            if let scrollView = current as? UIScrollView, scrollView !== self {
                scrollView.isScrollEnabled = enabled
                return
            }
            view = current.superview
        }
    }

    override func resignFirstResponder() -> Bool {
        setParentScrollEnabled(true)
        return super.resignFirstResponder()
    }
}
