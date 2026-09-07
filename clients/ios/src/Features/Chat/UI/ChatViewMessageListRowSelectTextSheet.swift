import SwiftUI
import UIKit

struct ChatViewMessageListRowSelectTextSheet: View {
    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                                .foregroundColor(ThemeColor.secondary)
                        }
                        .accessibilityLabel("Close text selection")
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
                                .frame(width: ThemeTokens.Text.m, height: ThemeTokens.Text.m)
                                .foregroundColor(copied ? ThemeColor.success : ThemeColor.secondary)
                                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                        }
                        .accessibilityLabel(copied ? "Text copied" : "Copy all text")
                    }
                }
                .themedNavChrome()
        }
        .presentationBackground(theme.palette.background)
    }
}
