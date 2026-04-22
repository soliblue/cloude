import SwiftUI

struct GitViewCommitRow: View {
    let commit: GitCommit
    @Environment(\.appAccent) private var appAccent

    var body: some View {
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
                        .foregroundColor(.secondary)
                    Text(commit.date, style: .relative)
                        .appFont(size: ThemeTokens.Text.s)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
    }
}
