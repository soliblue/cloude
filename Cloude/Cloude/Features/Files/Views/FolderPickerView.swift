import SwiftUI
import CloudeShared

struct FolderPickerView: View {
    let environmentStore: EnvironmentStore
    var environmentId: UUID?
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State var currentPath: String = "~"
    @State private var entries: [FileEntry] = []
    @State private var isLoading = false
    @State var showHidden = false

    private var folders: [FileEntry] {
        let dirs = entries.filter { $0.isDirectory }
        let visible = dirs.filter { !$0.name.hasPrefix(".") }
        let hidden = dirs.filter { $0.name.hasPrefix(".") }
        return showHidden ? visible + hidden : visible
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
        NavigationStack {
            VStack(spacing: 0) {
                pathBar
                Divider()
                folderList
                Divider()
                selectButton
            }
            .background(Color.themeBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.themeSecondary, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: DS.Icon.s, weight: .medium))
                    }
                }
            }
        }
        .presentationBackground(Color.themeBackground)
        .onAppear { loadDirectory(); syncListing() }
        .onChange(of: currentDirectoryListing) { _, _ in syncListing() }
        .onChange(of: currentPathError) { _, _ in syncListing() }
    }

    private var folderList: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if folders.isEmpty {
                ContentUnavailableView("No Folders", systemImage: "folder", description: Text("This folder has no subfolders"))
            } else {
                List(folders) { entry in
                    FolderRow(entry: entry) {
                        navigateTo(entry.path)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var selectButton: some View {
        Button(action: selectCurrentFolder) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Select \"\(currentFolderName)\"")
                    .font(.system(size: DS.Text.m))
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .buttonStyle(.borderedProminent)
        .padding()
    }

    private var currentFolderName: String {
        currentPath.lastPathComponent
    }

    private func selectCurrentFolder() {
        onSelect(currentPath)
        dismiss()
    }

    func navigateTo(_ path: String) {
        currentPath = path
        loadDirectory()
    }

    private func loadDirectory() {
        isLoading = true
        entries = []
        connection?.listDirectory(path: currentPath)
    }

    private func syncListing() {
        if let currentDirectoryListing {
            entries = currentDirectoryListing
            isLoading = false
        } else if currentPathError != nil {
            entries = []
            isLoading = false
        }
    }
}
