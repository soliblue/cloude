import SwiftUI
import CloudeShared

extension FolderPickerView {
    var currentFolderName: String {
        currentPath.lastPathComponent
    }

    func selectCurrentFolder() {
        onSelect(currentPath)
        dismiss()
    }

    func navigateTo(_ path: String) {
        currentPath = path
        loadDirectory()
    }

    func loadDirectory() {
        if currentPath == "~", let defaultWorkingDirectory {
            currentPath = defaultWorkingDirectory
        }
        if currentPath == "~" {
            isLoading = connection?.isReady != true
            entries = []
            return
        }
        isLoading = true
        entries = []
        connection?.files.listDirectory(path: currentPath)
    }

    func syncListing() {
        if let currentDirectoryListing {
            entries = currentDirectoryListing
            isLoading = false
        } else if currentPathError != nil {
            entries = []
            isLoading = false
        }
    }
}
