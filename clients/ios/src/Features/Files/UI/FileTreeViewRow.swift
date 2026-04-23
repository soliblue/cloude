import SwiftUI

struct FileTreeViewRow: View {
    let session: Session
    let node: FileNodeDTO
    let depth: Int
    let store: FileTreeStore
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
            Button {
                if node.isDirectory {
                    if store.expanded.contains(node.path) {
                        store.expanded.remove(node.path)
                    } else {
                        store.expanded.insert(node.path)
                        if store.children[node.path] == nil, let endpoint = session.endpoint {
                            Task {
                                store.loading.insert(node.path)
                                let listing = await FilesService.list(
                                    endpoint: endpoint, session: session, path: node.path)
                                if let listing {
                                    store.children[listing.path] = listing.entries
                                }
                                store.loading.remove(node.path)
                            }
                        }
                    }
                } else {
                    store.previewNode = node
                }
            } label: {
                HStack(spacing: ThemeTokens.Spacing.s) {
                    Image(
                        systemName: node.isDirectory
                            ? (store.expanded.contains(node.path) ? "chevron.down" : "chevron.right")
                            : "circle.fill"
                    )
                    .appFont(size: ThemeTokens.Icon.s)
                    .foregroundColor(.secondary)
                    .frame(width: ThemeTokens.Icon.m)
                    .opacity(node.isDirectory ? 1 : 0)
                    Image(systemName: node.isDirectory ? "folder.fill" : "doc")
                        .appFont(size: ThemeTokens.Icon.m)
                        .foregroundColor(node.isDirectory ? ThemeColor.blue : .secondary)
                    Text(node.name)
                        .appFont(size: ThemeTokens.Text.m)
                        .lineLimit(1)
                        .foregroundColor(theme.palette.colorScheme == .dark ? .white : .black)
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
            .buttonStyle(.plain)

            if store.expanded.contains(node.path) {
                ForEach(store.children[node.path] ?? [], id: \.path) { child in
                    FileTreeViewRow(session: session, node: child, depth: depth + 1, store: store)
                }
            }
        }
    }

}
