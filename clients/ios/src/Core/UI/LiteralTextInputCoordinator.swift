import Foundation
import SwiftUI
import UIKit

final class LiteralTextInputCoordinator: NSObject, UITextViewDelegate {
    var text: Binding<String>
    var focused: Binding<Bool>

    init(text: Binding<String>, focused: Binding<Bool>) {
        self.text = text
        self.focused = focused
    }

    func updateText(_ view: UITextView, value: String) {
        if view.text != value && view.markedTextRange == nil {
            let selection = view.selectedRange
            view.text = value
            let start = min(selection.location, (value as NSString).length)
            view.selectedRange = NSRange(
                location: start, length: min(selection.length, (value as NSString).length - start))
        }
    }

    func textViewDidChange(_ textView: UITextView) { text.wrappedValue = textView.text }

    func textViewDidBeginEditing(_ textView: UITextView) {
        Task { @MainActor [weak textView] in
            if textView?.isFirstResponder == true { self.focused.wrappedValue = true }
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        Task { @MainActor [weak textView] in
            if textView?.isFirstResponder == false { self.focused.wrappedValue = false }
        }
    }
}
