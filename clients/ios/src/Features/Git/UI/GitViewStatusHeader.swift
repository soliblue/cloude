import SwiftUI

struct GitViewStatusHeader: View {
    let status: GitStatus
    let session: Session
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.s) {
            if let repo = repoName {
                Text(repo)
                    .appFont(size: ThemeTokens.Text.m, weight: .semibold)
                Text("/")
                    .appFont(size: ThemeTokens.Text.m, weight: .regular)
                    .foregroundColor(.secondary)
            }
            Text(status.branch)
                .appFont(size: ThemeTokens.Text.m, weight: .semibold)
            if status.ahead > 0 {
                Label("\(status.ahead)", systemImage: "arrow.up")
                    .appFont(size: ThemeTokens.Text.s)
            }
            if status.behind > 0 {
                Label("\(status.behind)", systemImage: "arrow.down")
                    .appFont(size: ThemeTokens.Text.s)
            }
            Spacer()
            let totalAdd = status.changes.compactMap(\.additions).reduce(0, +)
            let totalDel = status.changes.compactMap(\.deletions).reduce(0, +)
            if totalAdd > 0 {
                Text("+\(totalAdd)")
                    .appFont(size: ThemeTokens.Text.s, weight: .medium, design: .monospaced)
                    .foregroundColor(ThemeColor.success)
            }
            if totalDel > 0 {
                Text("-\(totalDel)")
                    .appFont(size: ThemeTokens.Text.s, weight: .medium, design: .monospaced)
                    .foregroundColor(ThemeColor.danger)
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
