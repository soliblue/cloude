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

    private var connection: Connection? {
        environmentStore.connectionStore.connection(for: environmentId)
    }

    private var currentDirectoryListings: [String: [FileEntry]] {
        connection?.files.directoryListings ?? [:]
    }

    var body: some View {
        Group {
            if let connection {
                ConnectionObserver(connection: connection) { _ in
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
                List(state.visibleNodes) { node in
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
            connection?.files.listDirectory(path: path)
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
        connection?.files.listDirectory(path: path)
    }

    private func refreshExpanded() {
        guard let path = resolvedRootPath else { return }
        state.refresh(rootPath: path) { dirPath in
            connection?.files.listDirectory(path: dirPath)
        }
    }

    private func toggleFolder(_ path: String) {
        withAnimation(.easeOut(duration: DS.Duration.s)) {
            state.toggleFolder(path) {
                connection?.files.listDirectory(path: path)
            }
        }
    }

    private func syncListings() {
        if let resolvedRootPath {
            withAnimation(.easeOut(duration: DS.Duration.s)) {
                state.syncListings(currentDirectoryListings, rootPath: resolvedRootPath)
            }
        }
    }
}
