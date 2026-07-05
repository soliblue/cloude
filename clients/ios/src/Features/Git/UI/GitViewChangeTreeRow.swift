import SwiftUI

struct GitViewChangeTreeRow: View {
    let node: GitChangeTreeNode
    let depth: Int
    @Binding var collapsed: Set<String>
    let onTap: (GitChange) -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let change = node.change {
                GitViewChangeRow(change: change, showsDirectory: false) { onTap(change) }
                    .padding(.leading, indent + ThemeTokens.Icon.m + ThemeTokens.Spacing.s)
                    .padding(.vertical, ThemeTokens.Spacing.xs)
            } else {
                Button {
                    if collapsed.contains(node.path) {
                        collapsed.remove(node.path)
                    } else {
                        collapsed.insert(node.path)
                    }
                } label: {
                    HStack(spacing: ThemeTokens.Spacing.s) {
                        Image(
                            systemName: collapsed.contains(node.path)
                                ? "chevron.right" : "chevron.down"
                        )
                        .appFont(size: ThemeTokens.Icon.s)
                        .foregroundColor(ThemeColor.secondary)
                        .frame(width: ThemeTokens.Icon.m)
                        Image(systemName: "folder.fill")
                            .appFont(size: ThemeTokens.Icon.m)
                            .foregroundColor(ThemeColor.blue)
                        Text(node.name)
                            .appFont(size: ThemeTokens.Text.m)
                            .lineLimit(1)
                            .foregroundColor(
                                theme.palette.colorScheme == .dark ? .white : .black)
                        Spacer()
                    }
                    .padding(.leading, indent)
                    .padding(.vertical, ThemeTokens.Spacing.xs)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if !collapsed.contains(node.path) {
                    ForEach(node.children) { child in
                        GitViewChangeTreeRow(
                            node: child, depth: depth + 1, collapsed: $collapsed, onTap: onTap)
                    }
                }
            }
        }
    }

    private var indent: CGFloat {
        CGFloat(depth) * ThemeTokens.Spacing.m
    }
}
