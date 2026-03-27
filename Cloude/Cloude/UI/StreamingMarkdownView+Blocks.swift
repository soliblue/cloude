import SwiftUI
import UIKit

struct CodeBlock: View {
    let code: String
    let language: String?
    @AppStorage("wrapCodeLines") private var defaultWrap = true
    @AppStorage("showCodeLineNumbers") private var defaultLineNumbers = true
    @State private var wrapOverride: Bool?
    @State private var lineNumbersOverride: Bool?
    @State private var copied = false

    private var wrap: Bool { wrapOverride ?? defaultWrap }
    private var lineNumbers: Bool { lineNumbersOverride ?? defaultLineNumbers }
    private var lines: [String] { code.components(separatedBy: "\n") }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(Color.gray.opacity(DS.Opacity.strong))
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
            Button { lineNumbersOverride = !lineNumbers } label: {
                Image(systemName: lineNumbers ? "list.number" : "list.bullet")
                    .font(.system(size: DS.Text.s))
                    .foregroundStyle(.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            Divider().frame(height: DS.Size.s)
            Button { wrapOverride = !wrap } label: {
                Image(systemName: wrap ? "text.word.spacing" : "arrow.left.and.right.text.vertical")
                    .font(.system(size: DS.Text.s))
                    .foregroundStyle(.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            Divider().frame(height: DS.Size.s)
            Button {
                UIPasteboard.general.string = code
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
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
                if lineNumbers {
                    lineNumberColumn
                }
                Text(SyntaxHighlighter.highlight(code, language: language))
                    .font(.system(size: DS.Text.s, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DS.Spacing.m)
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    if lineNumbers {
                        lineNumberColumn
                    }
                    Text(SyntaxHighlighter.highlight(code, language: language))
                        .font(.system(size: DS.Text.s, design: .monospaced))
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(DS.Spacing.m)
                }
            }
        }
    }

    private var lineNumberColumn: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, _ in
                Text("\(index + 1)")
                    .font(.system(size: DS.Text.s, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(DS.Opacity.half))
                    .frame(height: lineHeight)
            }
        }
        .padding(.leading, DS.Spacing.m)
        .padding(.vertical, DS.Spacing.m)
        .padding(.trailing, DS.Spacing.xs)
        .background(Color.themeSecondary)
    }

    private var lineHeight: CGFloat {
        UIFont.monospacedSystemFont(ofSize: DS.Text.s, weight: .regular).lineHeight
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
