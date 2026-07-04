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
                .foregroundStyle(.secondary)
                .padding(ThemeTokens.Spacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ThemeColor.blue.opacity(ThemeTokens.Opacity.s))
        case .binary:
            Text(line.text)
                .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                .foregroundStyle(.secondary)
                .padding(ThemeTokens.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .context:
            row(tint: nil) {
                CodeText(line.text.isEmpty ? " " : line.text)
                    .highlightLanguage(HighlightLanguageResolver.resolve(language))
                    .appFont(size: ThemeTokens.Text.s, design: .monospaced)
            }
        case .added:
            row(tint: ThemeColor.success) {
                Text(changedAttributed(tint: ThemeColor.success))
                    .appFont(size: ThemeTokens.Text.s, design: .monospaced)
            }
        case .removed:
            row(tint: ThemeColor.danger) {
                Text(changedAttributed(tint: ThemeColor.danger))
                    .appFont(size: ThemeTokens.Text.s, design: .monospaced)
            }
        }
    }

    private func row<Content: View>(tint: Color?, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: ThemeTokens.Spacing.s) {
            Text(gutter)
                .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                .foregroundStyle(.tertiary)
                .frame(width: 34, alignment: .trailing)
            Text(sign)
                .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                .foregroundStyle((tint ?? .secondary).opacity(ThemeTokens.Opacity.l))
                .frame(width: ThemeTokens.Spacing.m, alignment: .leading)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, ThemeTokens.Spacing.xs)
        .padding(.horizontal, ThemeTokens.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((tint ?? .clear).opacity(tint == nil ? 0 : ThemeTokens.Opacity.s))
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

    private func changedAttributed(tint: Color) -> AttributedString {
        var attr = AttributedString(line.text.isEmpty ? " " : line.text)
        if let range = line.changedRange {
            let chars = attr.characters
            let start = chars.index(
                chars.startIndex, offsetBy: range.lowerBound, limitedBy: chars.endIndex)
            let end = chars.index(
                chars.startIndex, offsetBy: range.upperBound, limitedBy: chars.endIndex)
            if let start, let end, start < end {
                attr[start..<end].backgroundColor = tint.opacity(ThemeTokens.Opacity.l)
                attr[start..<end].inlinePresentationIntent = .stronglyEmphasized
            }
        }
        return attr
    }
}
