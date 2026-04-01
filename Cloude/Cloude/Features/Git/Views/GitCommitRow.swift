import SwiftUI
import CloudeShared

struct GitCommitRow: View {
    let commit: GitCommit

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(commit.message)
                    .font(.system(size: DS.Text.m))
                    .lineLimit(1)
                HStack(spacing: DS.Spacing.s) {
                    Text(commit.hash)
                        .font(.system(size: DS.Text.s, design: .monospaced))
                        .foregroundColor(.accentColor)
                    Text(commit.author)
                        .font(.system(size: DS.Text.s))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(commit.date, style: .relative)
                .font(.system(size: DS.Text.s))
                .foregroundColor(.secondary)
        }
    }
}
