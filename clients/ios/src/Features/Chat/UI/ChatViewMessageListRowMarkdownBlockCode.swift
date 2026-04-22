import SwiftUI
import UIKit

struct ChatViewMessageListRowMarkdownBlockCode: View {
    let code: String
    let language: String?
    @AppStorage(StorageKey.wrapCodeLines) private var defaultWrap = true
    @Environment(\.theme) private var theme
    @State private var wrapOverride: Bool?
    @State private var copied = false

    private var wrap: Bool { wrapOverride ?? defaultWrap }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(Color.gray.opacity(ThemeTokens.Opacity.m))
            content
        }
        .background(theme.palette.elevated)
        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.s))
    }

    private var toolbar: some View {
        HStack(spacing: ThemeTokens.Spacing.s) {
            if let lang = language, !lang.isEmpty {
                Text(lang)
                    .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                wrapOverride = !wrap
            } label: {
                Image(
                    systemName: wrap
                        ? "text.word.spacing" : "arrow.left.and.right.text.vertical"
                )
                .appFont(size: ThemeTokens.Text.s)
                .foregroundStyle(.secondary)
                .contentTransition(.symbolEffect(.replace))
            }
            Divider().frame(height: ThemeTokens.Text.s)
            Button {
                UIPasteboard.general.string = code
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + ThemeTokens.Delay.xl) {
                    copied = false
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .appFont(size: ThemeTokens.Text.s)
                    .frame(width: ThemeTokens.Text.s, height: ThemeTokens.Text.s)
                    .foregroundStyle(copied ? ThemeColor.success : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .padding(.horizontal, ThemeTokens.Spacing.m)
        .padding(.vertical, ThemeTokens.Spacing.s)
    }

    @ViewBuilder private var content: some View {
        if wrap {
            HStack(alignment: .top, spacing: 0) {
                Text(ChatMarkdownSyntaxHighlighter.highlight(code, language: language))
                    .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(ThemeTokens.Spacing.m)
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    Text(ChatMarkdownSyntaxHighlighter.highlight(code, language: language))
                        .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(ThemeTokens.Spacing.m)
                }
            }
        }
    }
}
