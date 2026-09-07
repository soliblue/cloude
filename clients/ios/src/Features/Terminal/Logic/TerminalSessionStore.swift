import Foundation
import Observation

@MainActor @Observable final class TerminalSessionStore {
    let connectionKey: String
    var snapshot: TerminalSnapshot
    var connected = false
    var error: String?
    var gap: String?
    var inputError: String?
    var terminating = false
    @ObservationIgnored var followGeneration = UUID()
    @ObservationIgnored var lastSeq = -1
    @ObservationIgnored var replayThrough: Int
    @ObservationIgnored let writerId = UUID()
    @ObservationIgnored var nextInputSequence = 0
    @ObservationIgnored var inFlightSequence: Int?
    @ObservationIgnored var inputs: [TerminalInput] = []
    @ObservationIgnored let renderer: TerminalRenderer
    @ObservationIgnored var lastAccess = Date.now

    init(snapshot: TerminalSnapshot, connectionKey: String) {
        self.connectionKey = connectionKey
        self.snapshot = snapshot
        replayThrough = snapshot.lastSeq
        renderer = TerminalRenderer(cols: snapshot.cols, rows: snapshot.rows)
    }

    var canInput: Bool { connected && snapshot.isRunning && inputError == nil && !terminating }

    func apply(_ data: Data) {
        if let event = try? JSONDecoder().decode(TerminalEvent.self, from: data) {
            if event.type == "terminal_ready",
                let updated = try? JSONDecoder().decode(TerminalSnapshot.self, from: data),
                updated.id == snapshot.id
            {
                snapshot = updated
                renderer.fitToViewport()
                connected = updated.isRunning
            } else if event.type == "terminal_gap", let firstSeq = event.firstSeq, firstSeq > lastSeq + 1 {
                gap =
                    "Some terminal output is no longer available. The screen was reset; earlier terminal state may be missing."
                lastSeq = firstSeq - 1
                renderer.reset()
            } else if let seq = event.seq, seq > lastSeq {
                if event.type == "terminal_output", let base64 = event.deltaBase64,
                    let bytes = Data(base64Encoded: base64)
                {
                    renderer.feed(bytes, allowResponses: connected && seq > replayThrough && gap == nil)
                    lastSeq = seq
                } else if event.type == "terminal_state",
                    let updated = try? JSONDecoder().decode(TerminalSnapshot.self, from: data),
                    updated.id == snapshot.id
                {
                    if !connected { renderer.resize(cols: updated.cols, rows: updated.rows) }
                    snapshot = updated
                    lastSeq = seq
                    if !updated.isRunning { connected = false }
                }
            }
        }
    }
}
