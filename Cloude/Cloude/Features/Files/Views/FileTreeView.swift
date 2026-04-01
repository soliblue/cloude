import SwiftUI
import CloudeShared

struct FileTreeView: View {
    let connection: ConnectionManager
    var rootPath: String?
    var environmentId: UUID?
    @ObservedObject var state: FileTreeState
    @State var selectedFile: FileEntry?

    private var defaultWorkingDirectory: String? {
        connection.connection(for: environmentId)?.defaultWorkingDirectory?.nilIfEmpty
    }

    private var resolvedRootPath: String? {
        rootPath?.nilIfEmpty ?? defaultWorkingDirectory
    }

    private var visibleNodes: [FileTreeNode] {
        var nodes: [FileTreeNode] = []
        appendNodes(from: state.rootEntries, depth: 0, into: &nodes)
        return nodes
    }

    var body: some View {
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
            FilePreviewView(file: file, connection: connection, environmentId: environmentId)
        }
        .onAppear { loadRootIfNeeded() }
        .onChange(of: rootPath) { _, _ in resetAndLoad() }
        .onChange(of: defaultWorkingDirectory) { _, newValue in
            guard rootPath == nil, let newValue, !newValue.isEmpty, state.isInitialLoad else { return }
            resetAndLoad()
        }
        .onReceive(connection.events) { event in
            if case let .directoryListing(path, entries, envId) = event, envId == environmentId {
                guard let resolved = resolvedRootPath else { return }
                withAnimation(.easeOut(duration: DS.Duration.s)) {
                    state.applyListing(path: path, entries: entries, rootPath: resolved)
                }
            }
        }
    }

    private func loadRootIfNeeded() {
        guard let path = resolvedRootPath else { return }
        if state.isInitialLoad {
            connection.listDirectory(path: path, environmentId: environmentId)
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
        connection.listDirectory(path: path, environmentId: environmentId)
    }

    private func refreshExpanded() {
        guard let path = resolvedRootPath else { return }
        state.refresh(rootPath: path) { dirPath in
            connection.listDirectory(path: dirPath, environmentId: environmentId)
        }
    }

    private func toggleFolder(_ path: String) {
        withAnimation(.easeOut(duration: DS.Duration.s)) {
            state.toggleFolder(path) {
                connection.listDirectory(path: path, environmentId: environmentId)
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
