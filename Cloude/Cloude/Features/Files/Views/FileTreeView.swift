import SwiftUI
import CloudeShared

struct FileTreeView: View {
    let environmentStore: EnvironmentStore
    var rootPath: String?
    var environmentId: UUID?
    var isVisible: Bool
    @ObservedObject var state: FileTreeState
    @State var selectedFile: FileEntry?

    private var defaultWorkingDirectory: String? {
        connection?.defaultWorkingDirectory?.nilIfEmpty
    }

    private var resolvedRootPath: String? {
        rootPath?.nilIfEmpty ?? defaultWorkingDirectory
    }

    private var connection: EnvironmentConnection? {
        environmentStore.connection(for: environmentId)
    }

    private var currentDirectoryListings: [String: [FileEntry]] {
        connection?.directoryListings ?? [:]
    }

    private var visibleNodes: [FileTreeNode] {
        var nodes: [FileTreeNode] = []
        appendNodes(from: state.rootEntries, depth: 0, into: &nodes)
        return nodes
    }

    var body: some View {
        Group {
            if let connection {
                EnvironmentConnectionObserver(connection: connection) { _ in
                    content
                }
            } else {
                content
            }
        }
    }

    private var content: some View {
        Group {
            if state.isInitialLoad {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.rootEntries.isEmpty {
                ContentUnavailableView("Empty Folder", systemImage: "folder", description: Text("This folder is empty"))
            } else {
                List(visibleNodes) { node in
                    FileTreeRow(node: node) {
                        if node.entry.isDirectory {
                            toggleFolder(node.entry.path)
                        } else {
                            selectedFile = node.entry
                        }
                    }
                    .listRowBackground(Color.themeBackground)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.themeBackground)
            }
        }
        .sheet(item: $selectedFile) { file in
            FilePreviewView(file: file, environmentStore: environmentStore, environmentId: environmentId)
        }
        .onAppear {
            if isVisible {
                loadRootIfNeeded()
                syncListings()
            }
        }
        .onChange(of: resolvedRootPath) { oldValue, newValue in
            if oldValue != newValue { resetAndLoad() }
        }
        .onChange(of: environmentId) { oldValue, newValue in
            if oldValue != newValue { resetAndLoad() }
        }
        .onChange(of: isVisible) { _, visible in
            if visible {
                loadRootIfNeeded()
                syncListings()
            }
        }
        .onChange(of: currentDirectoryListings) { _, _ in syncListings() }
    }

    private func loadRootIfNeeded() {
        guard let path = resolvedRootPath else { return }
        if state.isInitialLoad {
            connection?.listDirectory(path: path)
        } else {
            refreshExpanded()
        }
    }

    private func resetAndLoad() {
        guard let path = resolvedRootPath else {
            state.reset()
            return
        }
        state.reset()
        connection?.listDirectory(path: path)
    }

    private func refreshExpanded() {
        guard let path = resolvedRootPath else { return }
        state.refresh(rootPath: path) { dirPath in
            connection?.listDirectory(path: dirPath)
        }
    }

    private func toggleFolder(_ path: String) {
        withAnimation(.easeOut(duration: DS.Duration.s)) {
            state.toggleFolder(path) {
                connection?.listDirectory(path: path)
            }
        }
    }

    private func syncListings() {
        if let resolvedRootPath {
            withAnimation(.easeOut(duration: DS.Duration.s)) {
                if let entries = currentDirectoryListings[resolvedRootPath] {
                    state.applyListing(path: resolvedRootPath, entries: entries, rootPath: resolvedRootPath)
                }
                for path in state.expandedPaths {
                    if let entries = currentDirectoryListings[path] {
                        state.applyListing(path: path, entries: entries, rootPath: resolvedRootPath)
                    }
                }
            }
        }
    }

    private func appendNodes(from entries: [FileEntry], depth: Int, into nodes: inout [FileTreeNode]) {
        for entry in entries {
            let isExpanded = state.expandedPaths.contains(entry.path)
            let isLoading = state.loadingPaths.contains(entry.path)
            nodes.append(FileTreeNode(entry: entry, depth: depth, isExpanded: isExpanded, isLoading: isLoading))
            if entry.isDirectory && isExpanded, let children = state.childEntries[entry.path] {
                appendNodes(from: children, depth: depth + 1, into: &nodes)
            }
        }
    }
}
