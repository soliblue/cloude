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

    var visibleNodes: [FileTreeNode] {
        var nodes: [FileTreeNode] = []
        appendVisibleNodes(from: rootEntries, depth: 0, into: &nodes)
        return nodes
    }

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

    func syncListings(_ listings: [String: [FileEntry]], rootPath: String) {
        if let entries = listings[rootPath] {
            applyListing(path: rootPath, entries: entries, rootPath: rootPath)
        }
        for path in expandedPaths {
            if let entries = listings[path] {
                applyListing(path: path, entries: entries, rootPath: rootPath)
            }
        }
    }

    func reset() {
        rootEntries = []
        childEntries = [:]
        expandedPaths = []
        loadingPaths = []
        isInitialLoad = true
    }

    private func appendVisibleNodes(from entries: [FileEntry], depth: Int, into nodes: inout [FileTreeNode]) {
        for entry in entries {
            let isExpanded = expandedPaths.contains(entry.path)
            let isLoading = loadingPaths.contains(entry.path)
            nodes.append(FileTreeNode(entry: entry, depth: depth, isExpanded: isExpanded, isLoading: isLoading))
            if entry.isDirectory && isExpanded, let children = childEntries[entry.path] {
                appendVisibleNodes(from: children, depth: depth + 1, into: &nodes)
            }
        }
    }
}
