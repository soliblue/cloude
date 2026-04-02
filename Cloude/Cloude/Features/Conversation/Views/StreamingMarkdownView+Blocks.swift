import SwiftUI
import UIKit

struct CodeBlock: View {
    let code: String
    let language: String?
    @AppStorage("wrapCodeLines") private var defaultWrap = true
    @State private var wrapOverride: Bool?
    @State private var copied = false

    private var wrap: Bool { wrapOverride ?? defaultWrap }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(Color.gray.opacity(DS.Opacity.m))
            codeContent
        }
        .background(Color.themeSecondary)
        .cornerRadius(DS.Radius.s)
    }

    private var toolbar: some View {
        HStack(spacing: DS.Spacing.s) {
            if let lang = language, !lang.isEmpty {
                Text(lang)
                    .font(.system(size: DS.Text.s, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { wrapOverride = !wrap } label: {
                Image(systemName: wrap ? "text.word.spacing" : "arrow.left.and.right.text.vertical")
                    .font(.system(size: DS.Text.s))
                    .foregroundStyle(.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            Divider().frame(height: DS.Text.s)
            Button {
                UIPasteboard.general.string = code
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + DS.Delay.xl) { copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: DS.Text.s))
                    .foregroundStyle(copied ? Color.pastelGreen : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .padding(.horizontal, DS.Spacing.m)
        .padding(.vertical, DS.Spacing.s)
    }

    @ViewBuilder
    private var codeContent: some View {
        if wrap {
            HStack(alignment: .top, spacing: 0) {
                Text(SyntaxHighlighter.highlight(code, language: language))
                    .font(.system(size: DS.Text.s, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DS.Spacing.m)
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    Text(SyntaxHighlighter.highlight(code, language: language))
                        .font(.system(size: DS.Text.s, design: .monospaced))
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(DS.Spacing.m)
                }
            }
        }
    }
}

struct BlockquoteView: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(Color.themeSecondary)
                .frame(width: DS.Spacing.xs)
            Text(text)
                .font(.system(size: DS.Text.m))
                .italic()
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, DS.Spacing.m)
                .padding(.vertical, DS.Spacing.xs)
        }
    }
}

struct HorizontalRuleView: View {
    var body: some View {
        Divider()
            .padding(.vertical, DS.Spacing.s)
    }
}
