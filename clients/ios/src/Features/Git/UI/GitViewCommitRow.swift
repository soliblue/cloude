import SwiftUI

struct GitViewCommitRow: View {
    let commit: GitCommit
    var onTap: () -> Void = {}
    @Environment(\.appAccent) private var appAccent

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ThemeTokens.Spacing.m) {
                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                    Text(commit.subject)
                        .appFont(size: ThemeTokens.Text.m)
                        .lineLimit(1)
                    HStack(spacing: ThemeTokens.Spacing.s) {
                        Text(commit.sha)
                            .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                            .foregroundColor(appAccent.color)
                        Text(commit.author)
                            .appFont(size: ThemeTokens.Text.s)
                            .foregroundColor(ThemeColor.secondary)
                        Text(commit.date, style: .relative)
                            .appFont(size: ThemeTokens.Text.s)
                            .foregroundColor(ThemeColor.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .appFont(size: ThemeTokens.Text.s, weight: .semibold)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
