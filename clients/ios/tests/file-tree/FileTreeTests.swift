import Foundation

@main
struct FileTreeTests {
    @MainActor
    static func main() {
        let store = FileTreeStore()
        store.rootPath = "/root"
        let folder = FileNodeDTO(name: "src", path: "/root/src", isDirectory: true, size: nil, modifiedAt: nil, mimeType: nil)
        let file = FileNodeDTO(name: "README.md", path: "/root/README.md", isDirectory: false, size: 2, modifiedAt: nil, mimeType: "text/plain")
        let children = (0..<20_000).map { FileNodeDTO(name: "file\($0).swift", path: "/root/src/file\($0).swift", isDirectory: false, size: 1, modifiedAt: nil, mimeType: "text/plain") }
        FileTreeActions.setListing(FileListingDTO(path: "/root", entries: [folder, file]), path: "/root", store: store)
        FileTreeActions.setListing(FileListingDTO(path: "/root/src", entries: children), path: "/root/src", store: store)
        precondition(store.rows.count == 2)
        let started = ContinuousClock.now
        FileTreeActions.setExpanded(true, path: folder.path, store: store)
        precondition(store.rows.count == 20_002)
        precondition(store.rows[1].depth == 1)
        precondition(store.rows[20_000].node.path == children.last?.path)
        precondition(store.rows.last?.node.path == file.path)
        precondition(Set(store.rows.map(\.id)).count == store.rows.count)
        FileTreeActions.setExpanded(false, path: folder.path, store: store)
        precondition(store.rows.count == 2)
        FileTreeActions.setListing(nil, path: folder.path, store: store)
        precondition(store.failed.contains(folder.path))
        precondition(store.children[folder.path]?.count == 20_000)
        FileTreeActions.setExpanded(true, path: folder.path, store: store)
        FileTreeActions.setListing(FileListingDTO(path: folder.path, entries: []), path: folder.path, store: store)
        precondition(!store.failed.contains(folder.path))
        precondition(store.rows.count == 2)
        print("PASS: flat 20000-file expansion, stable paths/depths, collapse, offline preservation and deletion refresh in \(started.duration(to: .now))")
    }
}
