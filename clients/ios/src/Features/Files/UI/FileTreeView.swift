import SwiftUI

struct FileTreeView: View {
    let session: Session
    @Environment(\.theme) private var theme
    @State private var store = FileTreeStore()
    @State private var loadFailed = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: ThemeTokens.Spacing.m) {
                if loadFailed && (store.children[store.rootPath] ?? []).isEmpty {
                    Text("Unable to load files")
                        .appFont(size: ThemeTokens.Text.m)
                        .foregroundColor(.secondary)
                        .padding(ThemeTokens.Spacing.m)
                }
                ForEach(store.children[store.rootPath] ?? [], id: \.path) { node in
                    FileTreeViewRow(session: session, node: node, depth: 0, store: store)
                }
            }
            .padding(.vertical, ThemeTokens.Spacing.s)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.palette.background)
        .task {
            if let endpoint = session.endpoint, let path = session.path, !path.isEmpty {
                store.rootPath = path
                let listing = await FilesService.list(
                    endpoint: endpoint, session: session, path: path, showHidden: true)
                if let listing {
                    store.rootPath = listing.path
                    store.children[listing.path] = listing.entries
                    loadFailed = false
                } else {
                    loadFailed = true
                }
            }
        }
    }
}
