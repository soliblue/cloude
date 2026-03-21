import Foundation
import Network
import CloudeShared

extension AppDelegate {
    static let idleTimeoutSeconds: TimeInterval = 10 * 60

    struct TerminalEntry {
        let masterFD: Int32
        let process: Process
        let connection: NWConnection
        let terminalId: String?
        var idleTimer: DispatchSourceTimer?
        var lastTimeoutReset: Date = .distantPast
    }

    static var activeTerminals: [String: TerminalEntry] = [:]

    func terminalKey(_ terminalId: String?, connection: NWConnection) -> String {
        terminalId ?? "conn-\(ObjectIdentifier(connection))"
    }

    func handleTerminalExec(_ command: String, workingDirectory: String, terminalId: String?, connection: NWConnection) {
        let cwd = workingDirectory.isEmpty ? NSHomeDirectory() : workingDirectory.expandingTildeInPath
        let key = terminalKey(terminalId, connection: connection)
        Log.info("Terminal exec (PTY): \(command.prefix(80)) (cwd: \(cwd), id: \(key.prefix(12)))")

        if let existing = Self.activeTerminals[key] {
            existing.idleTimer?.cancel()
            existing.process.terminate()
            close(existing.masterFD)
            Self.activeTerminals.removeValue(forKey: key)
        }

        var masterFD: Int32 = 0
        var slaveFD: Int32 = 0
        var winSize = winsize(ws_row: 24, ws_col: 80, ws_xpixel: 0, ws_ypixel: 0)

        if openpty(&masterFD, &slaveFD, nil, nil, &winSize) != 0 {
            server.sendMessage(.terminalOutput(output: "Failed to create PTY", exitCode: 1, isError: true, terminalId: terminalId), to: connection)
            return
        }

        let userShell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: userShell)
        process.arguments = ["-l", "-c", command]
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        process.environment = ProcessInfo.processInfo.environment.merging([
            "TERM": "xterm-256color",
            "FORCE_COLOR": "1",
            "CLICOLOR_FORCE": "1"
        ]) { _, new in new }

        process.standardInput = FileHandle(fileDescriptor: slaveFD)
        process.standardOutput = FileHandle(fileDescriptor: slaveFD)
        process.standardError = FileHandle(fileDescriptor: slaveFD)

        do {
            try process.run()
        } catch {
            close(masterFD)
            close(slaveFD)
            server.sendMessage(.terminalOutput(output: error.localizedDescription, exitCode: 1, isError: true, terminalId: terminalId), to: connection)
            return
        }

        close(slaveFD)

        Self.activeTerminals[key] = TerminalEntry(masterFD: masterFD, process: process, connection: connection, terminalId: terminalId)
        resetTerminalIdleTimeout(key: key)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let bufferSize = 4096
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }

            while true {
                let bytesRead = read(masterFD, buffer, bufferSize)
                if bytesRead <= 0 { break }
                let data = Data(bytes: buffer, count: bytesRead)
                let text = String(data: data, encoding: .utf8) ?? ""
                if !text.isEmpty {
                    Task { @MainActor [weak self] in
                        self?.resetTerminalIdleTimeout(key: key)
                        self?.server.sendMessage(.terminalOutput(output: text, exitCode: nil, isError: false, terminalId: terminalId), to: connection)
                    }
                }
            }

            process.waitUntilExit()

            Task { @MainActor [weak self] in
                let exitCode = Int(process.terminationStatus)
                if let entry = Self.activeTerminals.removeValue(forKey: key) {
                    entry.idleTimer?.cancel()
                    close(masterFD)
                }
                self?.server.sendMessage(.terminalOutput(output: "", exitCode: exitCode, isError: exitCode != 0, terminalId: terminalId), to: connection)
            }
        }
    }
}
