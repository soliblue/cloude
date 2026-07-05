import HighlightSwift
import SwiftUI

struct GitDiffSheetLine: View {
    let line: GitDiffLine
    let language: String

    var body: some View {
        switch line.kind {
        case .hunk:
            Text(line.text.isEmpty ? "…" : line.text)
                .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                .foregroundStyle(ThemeColor.secondary)
                .padding(ThemeTokens.Spacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ThemeColor.blue.opacity(ThemeTokens.Opacity.s))
        case .binary:
            Text(line.text)
                .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                .foregroundStyle(ThemeColor.secondary)
                .padding(ThemeTokens.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .context:
            codeRow(tint: nil)
        case .added:
            codeRow(tint: ThemeColor.success)
        case .removed:
            codeRow(tint: ThemeColor.danger)
        }
    }

    private func codeRow(tint: Color?) -> some View {
        HStack(alignment: .top, spacing: ThemeTokens.Spacing.s) {
            Text(gutter)
                .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                .foregroundStyle(.tertiary)
                .frame(width: 34, alignment: .trailing)
            Text(sign)
                .appFont(size: ThemeTokens.Text.s, weight: .bold, design: .monospaced)
                .foregroundStyle((tint ?? ThemeColor.secondary).opacity(ThemeTokens.Opacity.l))
                .frame(width: ThemeTokens.Spacing.m, alignment: .leading)
            HStack(alignment: .top, spacing: 0) {
                if !indent.isEmpty {
                    Text(indent)
                        .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                }
                CodeText(code.isEmpty ? " " : code)
                    .highlightLanguage(HighlightLanguageResolver.resolve(language))
                    .appFont(size: ThemeTokens.Text.s, design: .monospaced)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, ThemeTokens.Spacing.xs)
        .padding(.horizontal, ThemeTokens.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((tint ?? .clear).opacity(tint == nil ? 0 : ThemeTokens.Opacity.xs))
    }

    private var indent: String {
        line.text.prefix { $0 == " " || $0 == "\t" }
            .map { $0 == "\t" ? String(repeating: "\u{00A0}", count: 4) : "\u{00A0}" }
            .joined()
    }

    private var code: String {
        let count = line.text.prefix { $0 == " " || $0 == "\t" }.count
        return String(line.text.dropFirst(count))
    }

    private var sign: String {
        switch line.kind {
        case .added: return "+"
        case .removed: return "-"
        default: return " "
        }
    }

    private var gutter: String {
        if let number = line.kind == .removed ? line.oldLine : line.newLine {
            return String(number)
        }
        return ""
    }
}
