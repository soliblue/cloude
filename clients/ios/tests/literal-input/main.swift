import Foundation
import SwiftUI
import UIKit

@main struct LiteralInputTests {
    @MainActor static func main() async {
        var text = ""
        var focused = false
        let textBinding = Binding(get: { text }, set: { text = $0 })
        let focusBinding = Binding(get: { focused }, set: { focused = $0 })
        let input = LiteralTextInput(
            text: textBinding, focused: focusBinding, label: "Message", lines: 1...6, font: UIFont(lineHeight: 20),
            tint: .label, enabled: true)
        let coordinator = input.makeCoordinator()
        let context = LiteralTextInput.Context(coordinator: coordinator)
        let view = input.makeUIView(context: context)
        precondition(view.smartQuotesType == .no && view.smartDashesType == .no && view.smartInsertDeleteType == .no)
        precondition(view.autocorrectionType == .no && view.autocapitalizationType == .none)
        input.updateUIView(view, context: context)
        let exact = "Draft pwd --help \"literal\" \\path\n日本語 👩🏽‍💻"
        view.text = exact
        coordinator.textViewDidChange(view)
        precondition(text == exact, "Native edits preserve exact bytes, line breaks and Unicode")
        view.selectedRange = NSRange(location: 4, length: 2)
        input.updateUIView(view, context: context)
        precondition(view.selectedRange == NSRange(location: 4, length: 2), "Unchanged text preserves selection")
        view.markedTextRange = NSObject()
        coordinator.updateText(view, value: "external")
        precondition(view.text == exact, "Active IME composition is not replaced")
        view.markedTextRange = nil
        coordinator.updateText(view, value: "a")
        precondition(view.text == "a" && view.selectedRange == NSRange(location: 1, length: 0))
        view.isFirstResponder = true
        coordinator.textViewDidBeginEditing(view)
        for _ in 0..<100 where !focused { await Task.yield() }
        precondition(focused)
        view.isFirstResponder = false
        coordinator.textViewDidEndEditing(view)
        for _ in 0..<100 where focused { await Task.yield() }
        precondition(!focused, "Native keyboard dismissal updates composer focus")
        focused = true
        input.updateUIView(view, context: context)
        precondition(view.isFirstResponder, "Programmatic composer focus reaches native input")
        view.measuredHeight = 10
        precondition(input.sizeThatFits(ProposedViewSize(width: 200), uiView: view, context: context)?.height == 20)
        view.measuredHeight = 200
        precondition(
            input.sizeThatFits(ProposedViewSize(width: 200), uiView: view, context: context)?.height == 120
                && view.isScrollEnabled)
        let schedule = LiteralTextInput(
            text: textBinding, focused: focusBinding, label: "Scheduled instruction", lines: 5...10,
            font: UIFont(lineHeight: 20), tint: .label, enabled: false)
        schedule.updateUIView(view, context: context)
        precondition(!view.isEditable && !view.isFirstResponder)
        view.measuredHeight = 20
        precondition(schedule.sizeThatFits(ProposedViewSize(width: 200), uiView: view, context: context)?.height == 100)
        print(
            "PASS literal native input traits, exact engineering/Unicode edits, IME and selection preservation, focus/dismissal, multiline sizing and disabled state"
        )
    }
}
