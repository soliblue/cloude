import Foundation
import Combine
import CloudeShared

@MainActor
class FileTreeState: ObservableObject {
    @Published var rootEntries: [FileEntry] = []
    @Published var childEntries: [String: [FileEntry]] = [:]
    @Published var expandedPaths: Set<String> = []
    @Published var loadingPaths: Set<String> = []
    @Published var isInitialLoad = true

    func applyListing(path: String, entries: [FileEntry], rootPath: String) {
        if path == rootPath && rootEntries.isEmpty && isInitialLoad {
            rootEntries = entries
            isInitialLoad = false
        } else if path == rootPath {
            rootEntries = entries
        } else {
            childEntries[path] = entries
        }
        loadingPaths.remove(path)
    }

    func toggleFolder(_ path: String, load: () -> Void) {
        if !expandedPaths.contains(path) {
            expandedPaths.insert(path)
            if childEntries[path] == nil {
                loadingPaths.insert(path)
                load()
            }
        } else {
            expandedPaths.remove(path)
        }
    }

    func refresh(rootPath: String, load: (String) -> Void) {
        load(rootPath)
        for path in expandedPaths {
            load(path)
        }
    }

    func reset() {
        rootEntries = []
        childEntries = [:]
        expandedPaths = []
        loadingPaths = []
        isInitialLoad = true
    }
}
