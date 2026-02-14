import SwiftUI
import CloudeShared

struct FolderPickerView: View {
    @ObservedObject var connection: ConnectionManager
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State var currentPath: String = "~"
    @State private var entries: [FileEntry] = []
    @State private var isLoading = false

    private var folders: [FileEntry] {
        entries.filter { $0.isDirectory }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pathBar
                Divider()
                folderList
                Divider()
                selectButton
            }
            .background(Color.oceanBackground)
            .navigationTitle("Select Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.oceanSecondary, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .presentationBackground(Color.oceanBackground)
        .onAppear { loadDirectory() }
        .onReceive(connection.events) { event in
            if case let .directoryListing(path, newEntries) = event {
                currentPath = path
                entries = newEntries
                isLoading = false
            }
        }
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
        connection.listDirectory(path: currentPath)
    }
}
