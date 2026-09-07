import Foundation
import SwiftUI
import UIKit

struct LiteralTextInput: UIViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    let label: String
    let lines: ClosedRange<Int>
    let font: UIFont
    let tint: UIColor
    let enabled: Bool

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textColor = .label
        view.autocapitalizationType = .none
        view.autocorrectionType = .no
        view.spellCheckingType = .no
        view.smartQuotesType = .no
        view.smartDashesType = .no
        view.smartInsertDeleteType = .no
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.text = text
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.focused = $focused
        view.font = font
        view.tintColor = tint
        view.isEditable = enabled
        view.accessibilityLabel = label
        context.coordinator.updateText(view, value: text)
        if focused && enabled && !view.isFirstResponder { view.becomeFirstResponder() }
        if (!focused || !enabled) && view.isFirstResponder { view.resignFirstResponder() }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        if let width = proposal.width, width > 0 && width.isFinite {
            let height = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
            let maximum = ceil(font.lineHeight * CGFloat(lines.upperBound))
            uiView.isScrollEnabled = height > maximum
            return CGSize(
                width: width, height: max(ceil(font.lineHeight * CGFloat(lines.lowerBound)), min(maximum, height)))
        }
        return nil
    }

    func makeCoordinator() -> LiteralTextInputCoordinator {
        LiteralTextInputCoordinator(text: $text, focused: $focused)
    }
}
