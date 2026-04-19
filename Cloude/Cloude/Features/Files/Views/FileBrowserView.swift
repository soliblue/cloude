import SwiftUI
import CloudeShared

struct FileBrowserView: View {
    let connection: ConnectionManager
    var rootPath: String?
    var environmentId: UUID?
    @State var currentPath: String = "~"
    @State var entries: [FileEntry] = []
    @State var selectedFile: FileEntry?
    @State var isLoading = false
    @State var pendingLoadPath: String?

    init(connection: ConnectionManager, rootPath: String? = nil, environmentId: UUID? = nil) {
        self.connection = connection
        self.rootPath = rootPath
        self.environmentId = environmentId
        _currentPath = State(initialValue: rootPath ?? "~")
    }

    private var defaultWorkingDirectory: String? {
        connection.connection(for: environmentId)?.defaultWorkingDirectory?.nilIfEmpty
    }

    private var resolvedRootPath: String? {
        rootPath?.nilIfEmpty ?? defaultWorkingDirectory
    }

    var body: some View {
        VStack(spacing: 0) {
            pathBar
            Divider()
            fileList
        }
        .sheet(item: $selectedFile) { file in
            FilePreviewView(file: file, connection: connection, environmentId: environmentId)
        }
        .onAppear {
            loadDirectory()
        }
        .onChange(of: rootPath) { _, newValue in
            let nextPath = newValue ?? defaultWorkingDirectory ?? "~"
            guard nextPath != currentPath else { return }
            currentPath = nextPath
            loadDirectory()
        }
        .onChange(of: defaultWorkingDirectory) { _, newValue in
            guard rootPath == nil, let newValue, !newValue.isEmpty else { return }
            guard currentPath == "~" || pendingLoadPath == "~" else { return }
            currentPath = newValue
            loadDirectory()
        }
        .onReceive(connection.events) { event in
            if case let .directoryListing(path, newEntries, envId) = event, envId == environmentId {
                currentPath = path
                entries = newEntries
                isLoading = false
                AppLogger.endInterval("files.directory", key: pendingLoadPath ?? path, details: "entries=\(newEntries.count)")
                pendingLoadPath = nil
            }
        }
    }

    private var fileList: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if entries.isEmpty {
                ContentUnavailableView("Empty Folder", systemImage: "folder", description: Text("This folder is empty"))
            } else {
                List(entries) { entry in
                    FileRow(entry: entry) {
                        if entry.isDirectory {
                            navigateTo(entry.path)
                        } else {
                            selectedFile = entry
                        }
                    }
                    .listRowBackground(Color.themeBackground)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.themeBackground)
            }
        }
    }

    func navigateTo(_ path: String) {
        currentPath = path
        loadDirectory()
    }

    private func loadDirectory() {
        if currentPath == "~", let resolvedRootPath {
            currentPath = resolvedRootPath
        }
        guard currentPath != "~" else {
            pendingLoadPath = nil
            isLoading = connection.connection(for: environmentId)?.phase != .authenticated
            entries = []
            return
        }
        pendingLoadPath = currentPath
        AppLogger.beginInterval("files.directory", key: currentPath)
        isLoading = true
        entries = []
        connection.listDirectory(path: currentPath, environmentId: environmentId)
    }
}
