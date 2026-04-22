import SwiftUI
import UIKit

struct ChatViewMessageListRowSelectTextSheet: View {
    let text: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ChatViewMessageListRowSelectTextSheetContent(text: text)
                .padding(.horizontal, ThemeTokens.Spacing.l)
                .padding(.top, ThemeTokens.Spacing.s)
                .background(theme.palette.background)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .appFont(size: ThemeTokens.Text.m, weight: .medium)
                                .foregroundColor(.secondary)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            UIPasteboard.general.string = text
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + ThemeTokens.Delay.xl) {
                                copied = false
                            }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .appFont(size: ThemeTokens.Text.m, weight: .medium)
                                .foregroundColor(copied ? ThemeColor.success : .secondary)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                }
                .themedNavChrome()
        }
        .presentationBackground(theme.palette.background)
    }
}

struct ChatViewMessageListRowSelectTextSheetContent: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = true
        view.backgroundColor = .clear
        view.font = .preferredFont(forTextStyle: .body)
        view.textColor = .label
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        view.text = text
        view.invalidateIntrinsicContentSize()
    }
}
