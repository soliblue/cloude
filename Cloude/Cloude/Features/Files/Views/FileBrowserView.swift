import SwiftUI
import CloudeShared

struct FileBrowserView: View {
    let environmentStore: EnvironmentStore
    var rootPath: String?
    var environmentId: UUID?
    @State var currentPath: String = "~"
    @State var entries: [FileEntry] = []
    @State var selectedFile: FileEntry?
    @State var isLoading = false
    @State var pendingLoadPath: String?

    init(environmentStore: EnvironmentStore, rootPath: String? = nil, environmentId: UUID? = nil) {
        self.environmentStore = environmentStore
        self.rootPath = rootPath
        self.environmentId = environmentId
        _currentPath = State(initialValue: rootPath ?? "~")
    }

    private var defaultWorkingDirectory: String? {
        connection?.defaultWorkingDirectory?.nilIfEmpty
    }

    private var resolvedRootPath: String? {
        rootPath?.nilIfEmpty ?? defaultWorkingDirectory
    }

    private var connection: EnvironmentConnection? {
        environmentStore.connection(for: environmentId)
    }

    private var currentDirectoryListing: [FileEntry]? {
        connection?.directoryListing(for: currentPath)
    }

    private var currentPathError: String? {
        connection?.pathError(for: currentPath)
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
        VStack(spacing: 0) {
            pathBar
            Divider()
            fileList
        }
        .sheet(item: $selectedFile) { file in
            FilePreviewView(file: file, environmentStore: environmentStore, environmentId: environmentId)
        }
        .onAppear {
            loadDirectory()
            syncListing()
        }
        .onChange(of: rootPath) { _, newValue in
            let nextPath = newValue ?? defaultWorkingDirectory ?? "~"
            guard nextPath != currentPath else { return }
            currentPath = nextPath
            loadDirectory()
        }
        .onChange(of: environmentId) { oldValue, newValue in
            if oldValue != newValue {
                let nextPath = resolvedRootPath ?? currentPath
                if !nextPath.isEmpty {
                    currentPath = nextPath
                }
                loadDirectory()
            }
        }
        .onChange(of: defaultWorkingDirectory) { _, newValue in
            guard rootPath == nil, let newValue, !newValue.isEmpty else { return }
            guard currentPath == "~" || pendingLoadPath == "~" else { return }
            currentPath = newValue
            loadDirectory()
        }
        .onChange(of: currentDirectoryListing) { _, _ in syncListing() }
        .onChange(of: currentPathError) { _, _ in syncListing() }
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
            isLoading = connection?.isReady != true
            entries = []
            return
        }
        pendingLoadPath = currentPath
        AppLogger.beginInterval("files.directory", key: currentPath)
        isLoading = true
        entries = []
        connection?.listDirectory(path: currentPath)
    }

    private func syncListing() {
        if let currentDirectoryListing {
            entries = currentDirectoryListing
            isLoading = false
            AppLogger.endInterval("files.directory", key: pendingLoadPath ?? currentPath, details: "entries=\(currentDirectoryListing.count)")
            pendingLoadPath = nil
        } else if let currentPathError {
            entries = []
            isLoading = false
            AppLogger.cancelInterval("files.directory", key: pendingLoadPath ?? currentPath, reason: currentPathError)
            pendingLoadPath = nil
        }
    }
}
