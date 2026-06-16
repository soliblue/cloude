import SwiftUI

struct GitViewStatusHeader: View {
    let summary: GitStatusSummary
    let session: Session
    @Environment(\.theme) private var theme
    @AppStorage(StorageKey.gitViewAsTree) private var viewAsTree = true

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.s) {
            if let repo = repoName {
                Text(repo)
                    .appFont(size: ThemeTokens.Text.m, weight: .semibold)
                Text("/")
                    .appFont(size: ThemeTokens.Text.m, weight: .regular)
                    .foregroundColor(.secondary)
            }
            Text(summary.branch)
                .appFont(size: ThemeTokens.Text.m, weight: .semibold)
            if summary.ahead > 0 {
                Label("\(summary.ahead)", systemImage: "arrow.up")
                    .appFont(size: ThemeTokens.Text.s)
            }
            if summary.behind > 0 {
                Label("\(summary.behind)", systemImage: "arrow.down")
                    .appFont(size: ThemeTokens.Text.s)
            }
            Spacer()
            if summary.additions > 0 {
                Text("+\(summary.additions)")
                    .appFont(size: ThemeTokens.Text.s, weight: .medium, design: .monospaced)
                    .foregroundColor(ThemeColor.success)
            }
            if summary.deletions > 0 {
                Text("-\(summary.deletions)")
                    .appFont(size: ThemeTokens.Text.s, weight: .medium, design: .monospaced)
                    .foregroundColor(ThemeColor.danger)
            }
            if summary.changeCount > 0 {
                Button {
                    viewAsTree.toggle()
                } label: {
                    Image(systemName: viewAsTree ? "list.bullet" : "list.bullet.indent")
                        .appFont(size: ThemeTokens.Icon.s)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, ThemeTokens.Spacing.l)
        .padding(.vertical, ThemeTokens.Spacing.m)
        .background(theme.palette.surface)
    }

    private var repoName: String? {
        if let path = session.path, !path.isEmpty {
            let leaf = (path as NSString).lastPathComponent
            return leaf.isEmpty ? nil : leaf
        }
        return nil
    }
}
