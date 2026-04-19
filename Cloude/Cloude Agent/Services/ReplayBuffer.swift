import Foundation
import CloudeShared

@MainActor
class ReplayBuffer {
    private struct Stamped {
        let seq: Int
        let at: Date
        let event: ReplayedEvent
    }

    private struct SessionBuffer {
        var entries: [Stamped] = []
        var nextSeq: Int = 1
    }

    private let maxEvents: Int = 200
    private let windowSeconds: TimeInterval = 60
    private var sessions: [String: SessionBuffer] = [:]

    func stamp(sessionId: String, event: (Int) -> ReplayedEvent) -> Int {
        var buf = sessions[sessionId] ?? SessionBuffer()
        let seq = buf.nextSeq
        buf.nextSeq += 1
        let stamped = Stamped(seq: seq, at: Date(), event: event(seq))
        buf.entries.append(stamped)
        prune(&buf)
        sessions[sessionId] = buf
        return seq
    }

    func replayFrom(sessionId: String, lastSeq: Int) -> (events: [ReplayedEvent], historyOnly: Bool) {
        guard var buf = sessions[sessionId] else {
            return ([], true)
        }
        prune(&buf)
        sessions[sessionId] = buf
        let firstAvailable = buf.entries.first?.seq ?? buf.nextSeq
        if lastSeq + 1 < firstAvailable {
            return ([], true)
        }
        let pending = buf.entries.filter { $0.seq > lastSeq }.map { $0.event }
        return (pending, false)
    }

    func release(sessionId: String) {
        sessions.removeValue(forKey: sessionId)
    }

    private func prune(_ buf: inout SessionBuffer) {
        let cutoff = Date().addingTimeInterval(-windowSeconds)
        buf.entries.removeAll { $0.at < cutoff }
        if buf.entries.count > maxEvents {
            buf.entries.removeFirst(buf.entries.count - maxEvents)
        }
    }
}
