import SwiftUI

struct GitViewChangeRow: View {
    let change: GitChange
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ThemeTokens.Spacing.s) {
                Text(badgeLetter)
                    .appFont(size: ThemeTokens.Text.s, weight: .bold, design: .monospaced)
                    .foregroundColor(.white)
                    .frame(width: ThemeTokens.Size.m, height: ThemeTokens.Icon.l)
                    .background(badgeColor)
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.s))
                HStack(spacing: 0) {
                    Text(directory)
                        .appFont(size: ThemeTokens.Text.m)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Text(leaf)
                        .appFont(size: ThemeTokens.Text.m, weight: .medium)
                        .lineLimit(1)
                }
                Spacer()
                if let additions = change.additions, additions > 0 {
                    Text("+\(additions)")
                        .appFont(size: ThemeTokens.Text.s, weight: .medium, design: .monospaced)
                        .foregroundColor(ThemeColor.success)
                }
                if let deletions = change.deletions, deletions > 0 {
                    Text("-\(deletions)")
                        .appFont(size: ThemeTokens.Text.s, weight: .medium, design: .monospaced)
                        .foregroundColor(ThemeColor.danger)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var badgeLetter: String {
        switch change.type {
        case .added: return "A"
        case .modified: return "M"
        case .deleted: return "D"
        case .renamed: return "R"
        case .copied: return "C"
        case .untracked: return "?"
        case .ignored: return "!"
        case .conflicted: return "U"
        }
    }

    private var badgeColor: Color {
        switch change.type {
        case .added, .untracked: return ThemeColor.success
        case .modified, .renamed, .copied: return ThemeColor.orange
        case .deleted, .conflicted: return ThemeColor.danger
        case .ignored: return ThemeColor.gray
        }
    }

    private var leaf: String {
        (change.path as NSString).lastPathComponent
    }

    private var directory: String {
        let dir = (change.path as NSString).deletingLastPathComponent
        return dir.isEmpty || dir == "." ? "" : dir + "/"
    }
}
