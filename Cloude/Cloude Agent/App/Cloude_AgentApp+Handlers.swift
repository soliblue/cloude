import Foundation
import Network
import CloudeShared

extension AppDelegate {
    func handleListDirectory(_ path: String, connection: NWConnection) {
        let expandedPath = path == "~" || path.isEmpty ? NSHomeDirectory() : path.expandingTildeInPath

        switch FileService.shared.listDirectory(at: expandedPath) {
        case .success(let entries):
            server.sendMessage(.directoryListing(path: expandedPath, entries: entries), to: connection)
        case .failure(let error):
            server.sendMessage(.error(message: error.localizedDescription), to: connection)
        }
    }

    func handleGetFile(_ path: String, connection: NWConnection, fullQuality: Bool = false) {
        Log.info("[GetFile] Request for: \(path), fullQuality: \(fullQuality)")

        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
            Log.info("[GetFile] Path is directory, returning listing instead")
            handleListDirectory(path, connection: connection)
            return
        }

        switch FileService.shared.getFile(at: path) {
        case .success(let result):
            Log.info("[GetFile] File loaded: \(result.size) bytes, needsChunking: \(result.needsChunking)")
            if result.needsChunking {
                let chunks = FileService.shared.chunkData(result.data)
                Log.info("[GetFile] Split into \(chunks.count) chunks")
                sendChunks(chunks, path: path, mimeType: result.mimeType, size: result.size, connection: connection)
            } else {
                let base64 = result.data.base64EncodedString()
                Log.info("[GetFile] Sending single message: \(base64.count) bytes")
                server.sendMessage(.fileContent(path: path, data: base64, mimeType: result.mimeType, size: result.size, truncated: false), to: connection)
            }
        case .failure(let error):
            Log.error("[GetFile] Error: \(error.localizedDescription)")
            server.sendMessage(.error(message: error.localizedDescription), to: connection)
        }
    }

    private func sendChunks(_ chunks: [Data], path: String, mimeType: String, size: Int64, connection: NWConnection) {
        for (index, chunk) in chunks.enumerated() {
            let base64 = chunk.base64EncodedString()
            Log.info("[FileChunk] Sending chunk \(index + 1)/\(chunks.count) (\(base64.count) bytes) for \(path)")
            server.sendMessage(.fileChunk(
                path: path,
                chunkIndex: index,
                totalChunks: chunks.count,
                data: base64,
                mimeType: mimeType,
                size: size
            ), to: connection)
        }
    }

    func handleGitStatus(_ path: String, connection: NWConnection) {
        let expandedPath = path.expandingTildeInPath
        switch GitService.getStatus(at: expandedPath) {
        case .success(let status):
            server.sendMessage(.gitStatusResult(status: status), to: connection)
        case .failure(let error):
            server.sendMessage(.error(message: error.localizedDescription), to: connection)
        }
    }

    func handleGitDiff(_ path: String, file: String?, connection: NWConnection) {
        let expandedPath = path.expandingTildeInPath
        switch GitService.getDiff(at: expandedPath, file: file) {
        case .success(let diff):
            server.sendMessage(.gitDiffResult(path: expandedPath, diff: diff), to: connection)
        case .failure(let error):
            server.sendMessage(.error(message: error.localizedDescription), to: connection)
        }
    }

    func handleGitCommit(_ path: String, message: String, files: [String], connection: NWConnection) {
        let expandedPath = path.expandingTildeInPath
        switch GitService.commit(at: expandedPath, message: message, files: files) {
        case .success(let output):
            server.sendMessage(.gitCommitResult(success: true, message: output), to: connection)
        case .failure(let error):
            server.sendMessage(.gitCommitResult(success: false, message: error.localizedDescription), to: connection)
        }
    }

    func handleTerminalExec(_ command: String, workingDirectory: String, connection: NWConnection) {
        let cwd = workingDirectory.isEmpty ? NSHomeDirectory() : workingDirectory.expandingTildeInPath
        Log.info("Terminal exec: \(command.prefix(80)) (cwd: \(cwd))")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", command]
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)
            process.environment = ProcessInfo.processInfo.environment.merging([
                "TERM": "xterm-256color",
                "FORCE_COLOR": "1",
                "CLICOLOR_FORCE": "1"
            ]) { _, new in new }

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
            } catch {
                self?.server.sendMessage(.terminalOutput(output: error.localizedDescription, exitCode: 1, isError: true), to: connection)
                return
            }

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            let output = stdout + (stderr.isEmpty ? "" : (stdout.isEmpty ? "" : "\n") + stderr)
            let code = Int(process.terminationStatus)
            self?.server.sendMessage(.terminalOutput(output: output, exitCode: code, isError: code != 0), to: connection)
        }
    }
}
