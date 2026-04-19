import SwiftUI

extension FileBrowserView {
    func loadDirectory() {
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
        connection?.files.listDirectory(path: currentPath)
    }

    func syncListing() {
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
