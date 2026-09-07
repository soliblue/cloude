import Foundation

enum FileTreeService {
    static func load(session: Session, path: String, store: FileTreeStore) async {
        if let endpoint = session.endpoint, !store.loading.contains(path) {
            store.loading.insert(path)
            FileTreeActions.setListing(
                await FilesService.list(endpoint: endpoint, session: session, path: path, showHidden: true),
                path: path, store: store)
        }
    }

    static func toggle(session: Session, node: FileNodeDTO, store: FileTreeStore) async {
        if store.failed.contains(node.path) {
            await load(session: session, path: node.path, store: store)
        } else {
            FileTreeActions.setExpanded(!store.expanded.contains(node.path), path: node.path, store: store)
            if store.expanded.contains(node.path), store.children[node.path] == nil {
                await load(session: session, path: node.path, store: store)
            }
        }
    }

    static func refresh(session: Session, store: FileTreeStore) async {
        if let path = session.path, !path.isEmpty {
            store.rootPath = path
            await load(session: session, path: path, store: store)
            for expanded in store.expanded {
                await load(session: session, path: expanded, store: store)
            }
        }
    }
}
