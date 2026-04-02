import SwiftUI
import CloudeShared

struct FileTreeRow: View {
    let node: FileTreeNode
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.s) {
                chevron
                icon
                Text(node.entry.name)
                    .font(.system(size: DS.Text.m))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.leading, CGFloat(node.depth) * DS.Spacing.l)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var chevron: some View {
        if node.entry.isDirectory {
            if node.isLoading {
                ProgressView()
                    .scaleEffect(DS.Scale.s)
                    .frame(width: DS.Text.s, height: DS.Text.s)
            } else {
                Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: DS.Text.s, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: DS.Text.s)
            }
        } else {
            Color.clear.frame(width: DS.Text.s)
        }
    }

    private var icon: some View {
        Image(systemName: node.entry.isDirectory ? "folder.fill" : fileIconName(for: node.entry.name))
            .font(.system(size: DS.Text.m))
            .foregroundColor(node.entry.isDirectory ? .blue : fileIconColor(for: node.entry.name))
    }
}
