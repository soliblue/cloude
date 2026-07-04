import SwiftUI

struct FileTreeView: View {
    let session: Session
    @Environment(\.theme) private var theme
    @State private var store = FileTreeStore()
    @State private var loadFailed = false
    @State private var isLoading = true

    private var rootEntries: [FileNodeDTO] { store.children[store.rootPath] ?? [] }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: ThemeTokens.Spacing.m) {
                if rootEntries.isEmpty {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, ThemeTokens.Spacing.xl)
                    } else if loadFailed {
                        ContentUnavailableView(
                            "Unable to load files", systemImage: "folder.badge.questionmark",
                            description: Text("Check your connection and try again."))
                            .padding(.top, ThemeTokens.Spacing.xl)
                    } else {
                        ContentUnavailableView(
                            "Empty folder", systemImage: "folder",
                            description: Text("There are no files here."))
                            .padding(.top, ThemeTokens.Spacing.xl)
                    }
                }
                ForEach(rootEntries, id: \.path) { node in
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
            } else {
                loadFailed = true
            }
            isLoading = false
        }
    }
}
