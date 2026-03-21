import Foundation
import Network
import CloudeShared

extension AppDelegate {
    func handleTerminalInput(_ text: String, terminalId: String?, connection: NWConnection) {
        let key = terminalKey(terminalId, connection: connection)
        if let entry = Self.activeTerminals[key] {
            resetTerminalIdleTimeout(key: key)
            let data = text.data(using: .utf8) ?? Data()
            data.withUnsafeBytes { bytes in
                if let baseAddress = bytes.baseAddress {
                    write(entry.masterFD, baseAddress, data.count)
                }
            }
        }
    }

    func cleanupTerminal(for connection: NWConnection) {
        let connId = ObjectIdentifier(connection)
        let keysToRemove = Self.activeTerminals.filter { $0.key.hasSuffix("\(connId)") || ObjectIdentifier($0.value.connection) == connId }.map(\.key)
        for key in keysToRemove {
            if let entry = Self.activeTerminals.removeValue(forKey: key) {
                entry.idleTimer?.cancel()
                entry.process.terminate()
                close(entry.masterFD)
            }
        }
        if !keysToRemove.isEmpty {
            Log.info("Cleaned up \(keysToRemove.count) terminal(s) for disconnected client")
        }
    }

    func resetTerminalIdleTimeout(key: String) {
        guard var entry = Self.activeTerminals[key] else { return }
        if Date().timeIntervalSince(entry.lastTimeoutReset) < 5 { return }

        entry.idleTimer?.cancel()
        entry.lastTimeoutReset = Date()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + Self.idleTimeoutSeconds)
        timer.setEventHandler { [weak self] in
            Log.info("Terminal idle timeout - killing PTY (\(key.prefix(12)))")
            if let entry = Self.activeTerminals.removeValue(forKey: key) {
                entry.process.terminate()
                close(entry.masterFD)
                self?.server.sendMessage(.terminalOutput(output: "\n[Idle timeout - session closed]", exitCode: 143, isError: true, terminalId: entry.terminalId), to: entry.connection)
            }
        }
        timer.resume()
        entry.idleTimer = timer
        Self.activeTerminals[key] = entry
    }
}
