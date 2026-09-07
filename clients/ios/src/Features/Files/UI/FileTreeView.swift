import SwiftUI

struct FileTreeView: View {
    let session: Session
    @Environment(\.theme) private var theme
    @State private var store = FileTreeStore()
    @State private var hasLoaded = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                if store.rows.isEmpty {
                    if !hasLoaded || store.loading.contains(store.rootPath) {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, ThemeTokens.Spacing.xl)
                    } else if store.failed.contains(store.rootPath) {
                        ContentUnavailableView {
                            Label("Unable to load files", systemImage: "folder.badge.questionmark")
                        } description: {
                            Text("Check your connection and try again.")
                        } actions: {
                            Button("Try again") {
                                Task { await FileTreeService.refresh(session: session, store: store) }
                            }
                        }
                    } else {
                        ContentUnavailableView(
                            "Empty folder", systemImage: "folder",
                            description: Text("There are no files here.")
                        )
                        .padding(.top, ThemeTokens.Spacing.xl)
                    }
                }
                ForEach(store.rows) { row in
                    FileTreeViewRow(session: session, node: row.node, depth: row.depth, store: store)
                }
            }
            .padding(.vertical, ThemeTokens.Spacing.s)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.palette.background)
        .task(id: session.connectionKey) {
            hasLoaded = false
            store = FileTreeStore()
            await FileTreeService.refresh(session: session, store: store)
            if !Task.isCancelled { hasLoaded = true }
        }
        .refreshable { await FileTreeService.refresh(session: session, store: store) }
    }
}
