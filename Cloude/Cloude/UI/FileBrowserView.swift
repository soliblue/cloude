import SwiftUI
import CloudeShared

struct FileBrowserView: View {
    @ObservedObject var connection: ConnectionManager
    var rootPath: String?
    @State var currentPath: String = "~"
    @State var entries: [FileEntry] = []
    @State var selectedFile: FileEntry?
    @State var isLoading = false

    init(connection: ConnectionManager, rootPath: String? = nil) {
        self.connection = connection
        self.rootPath = rootPath
        _currentPath = State(initialValue: rootPath ?? "~")
    }

    var body: some View {
        VStack(spacing: 0) {
            pathBar
            Divider()
            fileList
        }
        .sheet(item: $selectedFile) { file in
            FilePreviewView(file: file, connection: connection) { folderPath in
                navigateTo(folderPath)
            }
        }
        .onAppear {
            loadDirectory()
        }
        .onReceive(connection.events) { event in
            if case let .directoryListing(path, newEntries) = event {
                currentPath = path
                entries = newEntries
                isLoading = false
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
                }
                .listStyle(.plain)
            }
        }
    }

    func navigateTo(_ path: String) {
        currentPath = path
        loadDirectory()
    }

    private func loadDirectory() {
        isLoading = true
        entries = []
        connection.listDirectory(path: currentPath)
    }
}
