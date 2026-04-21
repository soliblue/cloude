import SwiftData
import SwiftUI

struct FileTreeView: View {
    let session: Session
    @Environment(\.theme) private var theme
    @State private var store = FileTreeStore()

    var body: some View {
        @Bindable var bindable = store
        ScrollView {
            LazyVStack(alignment: .leading, spacing: ThemeTokens.Spacing.m) {
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
                let listing = await FilesService.list(endpoint: endpoint, session: session, path: path)
                if let listing {
                    store.rootPath = listing.path
                    store.children[listing.path] = listing.entries
                }
            }
        }
        .sheet(item: $bindable.previewNode) { node in
            FilePreviewSheet(session: session, node: node)
                .environment(\.theme, theme)
        }
    }
}
