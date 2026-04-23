import SwiftUI

struct GitDiffSheetLine: View {
    let line: GitDiffLine

    var body: some View {
        switch line.kind {
        case .hunk:
            Text(line.text)
                .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                .foregroundStyle(.secondary)
                .padding(ThemeTokens.Spacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ThemeColor.blue.opacity(ThemeTokens.Opacity.s))
        case .added:
            row(prefix: "+", color: ThemeColor.success)
        case .removed:
            row(prefix: "-", color: ThemeColor.danger)
        case .context:
            row(prefix: " ", color: nil)
        case .binary:
            Text(line.text)
                .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                .foregroundStyle(.secondary)
                .padding(ThemeTokens.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func row(prefix: String, color: Color?) -> some View {
        HStack(spacing: ThemeTokens.Spacing.s) {
            Text(prefix)
                .frame(width: ThemeTokens.Spacing.m)
                .foregroundStyle((color ?? .secondary).opacity(ThemeTokens.Opacity.l))
            Text(line.text)
        }
        .appFont(size: ThemeTokens.Text.s, design: .monospaced)
        .padding(.vertical, ThemeTokens.Spacing.xs)
        .padding(.horizontal, ThemeTokens.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((color ?? .clear).opacity(color == nil ? 0 : ThemeTokens.Opacity.s))
    }
}
