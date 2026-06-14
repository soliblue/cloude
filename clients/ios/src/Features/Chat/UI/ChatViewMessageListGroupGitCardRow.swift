import SwiftUI

struct ChatViewMessageListGroupGitCardRow: View {
    let session: Session
    let change: ChatGitChange
    @Environment(\.filePreviewPresenter) private var presenter

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.s) {
            Text(badgeLetter)
                .appFont(size: ThemeTokens.Text.s, weight: .bold, design: .monospaced)
                .foregroundColor(badgeColor)
                .frame(width: ThemeTokens.Size.m)
            HStack(spacing: 0) {
                Text(directory)
                    .appFont(size: ThemeTokens.Text.s)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
                Text(leaf)
                    .appFont(size: ThemeTokens.Text.s, weight: .medium)
                    .lineLimit(1)
            }
            Spacer()
            if change.additions > 0 {
                Text("+\(change.additions)")
                    .appFont(size: ThemeTokens.Text.s, weight: .medium, design: .monospaced)
                    .foregroundColor(ThemeColor.success)
            }
            if change.deletions > 0 {
                Text("-\(change.deletions)")
                    .appFont(size: ThemeTokens.Text.s, weight: .medium, design: .monospaced)
                    .foregroundColor(ThemeColor.danger)
            }
            if change.type != .deleted {
                Button {
                    presenter.open(
                        session: session,
                        path: session.path.map {
                            ($0 as NSString).appendingPathComponent(change.path)
                        } ?? change.path)
                } label: {
                    Image(systemName: "arrow.up.forward")
                        .appFont(size: ThemeTokens.Icon.s)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
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
