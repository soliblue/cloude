import Foundation
import Network
import CloudeShared

extension AppDelegate {
    func handleListDirectory(_ path: String, connection: NWConnection) {
        let expandedPath = path == "~" || path.isEmpty ? NSHomeDirectory() : (path as NSString).expandingTildeInPath

        switch FileService.shared.listDirectory(at: expandedPath) {
        case .success(let entries):
            server.sendMessage(.directoryListing(path: expandedPath, entries: entries), to: connection)
        case .failure(let error):
            server.sendMessage(.error(message: error.localizedDescription), to: connection)
        }
    }

    func handleGetFile(_ path: String, connection: NWConnection) {
        switch FileService.shared.getFile(at: path) {
        case .success(let result):
            let base64 = result.data.base64EncodedString()
            server.sendMessage(.fileContent(path: path, data: base64, mimeType: result.mimeType, size: result.size), to: connection)
        case .failure(let error):
            server.sendMessage(.error(message: error.localizedDescription), to: connection)
        }
    }

    func handleGitStatus(_ path: String, connection: NWConnection) {
        let expandedPath = (path as NSString).expandingTildeInPath
        switch GitService.getStatus(at: expandedPath) {
        case .success(let status):
            server.sendMessage(.gitStatusResult(status: status), to: connection)
        case .failure(let error):
            server.sendMessage(.error(message: error.localizedDescription), to: connection)
        }
    }

    func handleGitDiff(_ path: String, file: String?, connection: NWConnection) {
        let expandedPath = (path as NSString).expandingTildeInPath
        switch GitService.getDiff(at: expandedPath, file: file) {
        case .success(let diff):
            server.sendMessage(.gitDiffResult(path: expandedPath, diff: diff), to: connection)
        case .failure(let error):
            server.sendMessage(.error(message: error.localizedDescription), to: connection)
        }
    }

    func handleGitCommit(_ path: String, message: String, files: [String], connection: NWConnection) {
        let expandedPath = (path as NSString).expandingTildeInPath
        switch GitService.commit(at: expandedPath, message: message, files: files) {
        case .success(let output):
            server.sendMessage(.gitCommitResult(success: true, message: output), to: connection)
        case .failure(let error):
            server.sendMessage(.gitCommitResult(success: false, message: error.localizedDescription), to: connection)
        }
    }
}
