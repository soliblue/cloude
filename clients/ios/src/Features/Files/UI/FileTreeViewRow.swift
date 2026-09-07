import SwiftUI

struct FileTreeViewRow: View {
    let session: Session
    let node: FileNodeDTO
    let depth: Int
    let store: FileTreeStore
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
            if node.isDirectory {
                Button {
                    Task { await FileTreeService.toggle(session: session, node: node, store: store) }
                } label: {
                    rowLabel
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink(value: node) {
                    rowLabel
                }
                .buttonStyle(.plain)
            }

        }
    }

    private var rowLabel: some View {
        HStack(spacing: ThemeTokens.Spacing.s) {
            Image(
                systemName: node.isDirectory
                    ? (store.expanded.contains(node.path) ? "chevron.down" : "chevron.right")
                    : "circle.fill"
            )
            .appFont(size: ThemeTokens.Text.s)
            .foregroundColor(ThemeColor.secondary)
            .frame(width: ThemeTokens.Text.m)
            .opacity(node.isDirectory ? 1 : 0)
            Image(systemName: node.isDirectory ? "folder.fill" : "doc")
                .appFont(size: ThemeTokens.Text.m)
                .foregroundColor(node.isDirectory ? ThemeColor.blue : ThemeColor.secondary)
            Text(node.name)
                .appFont(size: ThemeTokens.Text.m)
                .lineLimit(1)
                .foregroundColor(theme.palette.colorScheme == .dark ? .white : .black)
            if store.failed.contains(node.path) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.red)
                    .accessibilityLabel("Unable to open folder. Tap to retry.")
            }
            if store.loading.contains(node.path) {
                ProgressView().controlSize(.mini)
            }
            Spacer()
        }
        .padding(.leading, CGFloat(depth) * ThemeTokens.Spacing.m + ThemeTokens.Spacing.m)
        .padding(.vertical, ThemeTokens.Spacing.xs)
        .padding(.trailing, ThemeTokens.Spacing.m)
        .contentShape(Rectangle())
    }

}
