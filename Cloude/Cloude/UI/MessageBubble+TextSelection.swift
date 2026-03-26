import SwiftUI
import UIKit

struct TextSelectionSheet: View {
    let text: String
    @Environment(\.dismiss) private var dismiss
    @State private var showCopied = false

    var body: some View {
        NavigationStack {
            PlainSelectableText(text: text)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: DS.Icon.toolbar, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        CopyFeedback.perform(text, showToast: $showCopied)
                    } label: {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: DS.Icon.toolbar, weight: .semibold))
                            .foregroundColor(showCopied ? .pastelGreen : .secondary)
                    }
                }
            }
        }
    }
}

struct PlainSelectableText: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.backgroundColor = .clear
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textColor = .label
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.text = text
        textView.invalidateIntrinsicContentSize()
    }
}
