import SwiftUI
import Network
import CloudeShared

extension AppDelegate {
    func installSignalHandlers() {
        let signalCallback: @convention(c) (Int32) -> Void = { sig in
            let sigName = sig == SIGTERM ? "SIGTERM" : "SIGINT"
            Log.info("Received \(sigName), shutting down gracefully...")
            DispatchQueue.main.async {
                guard let delegate = NSApp.delegate as? AppDelegate else {
                    exit(0)
                }
                delegate.server.stop()
                Log.info("Server stopped, killing Claude processes...")
                let killed = ProcessMonitor.killAllClaudeProcesses()
                Log.info("Killed \(killed) Claude process(es), exiting")
                exit(0)
            }
        }
        signal(SIGTERM, signalCallback)
        signal(SIGINT, signalCallback)
    }

    func handleTranscribe(_ audioBase64: String, connection: NWConnection) {
        Log.info("Transcribe: received \(audioBase64.count) chars")
        Task {
            do {
                let text = try await WhisperService.shared.transcribe(audioBase64: audioBase64)
                Log.info("Transcribe: result '\(text.prefix(50))...'")
                await MainActor.run {
                    server.sendMessage(.transcription(text: text), to: connection)
                }
            } catch {
                Log.error("Transcribe failed: \(error.localizedDescription)")
                await MainActor.run {
                    server.sendMessage(.error(message: "Transcription failed: \(error.localizedDescription)"), to: connection)
                }
            }
        }
    }
}
