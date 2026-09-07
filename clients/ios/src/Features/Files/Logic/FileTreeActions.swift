import Foundation

enum FileTreeActions {
    static func rebuild(_ store: FileTreeStore) {
        var stack = (store.children[store.rootPath] ?? []).reversed().map { FileTreeEntry(node: $0, depth: 0) }
        var rows: [FileTreeEntry] = []
        while let row = stack.popLast() {
            rows.append(row)
            if store.expanded.contains(row.node.path) {
                stack.append(
                    contentsOf: (store.children[row.node.path] ?? []).reversed().map {
                        FileTreeEntry(node: $0, depth: row.depth + 1)
                    })
            }
        }
        store.rows = rows
    }

    static func setExpanded(_ expanded: Bool, path: String, store: FileTreeStore) {
        if expanded { store.expanded.insert(path) } else { store.expanded.remove(path) }
        rebuild(store)
    }

    static func setListing(_ listing: FileListingDTO?, path: String, store: FileTreeStore) {
        if let listing {
            store.children[path] = listing.entries
            store.failed.remove(path)
        } else {
            store.failed.insert(path)
        }
        store.loading.remove(path)
        rebuild(store)
    }
}
