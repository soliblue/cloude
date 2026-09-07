import Foundation
import Network

final class CodexJournalReplay {
    private let reader: CodexJournalReader
    private let connection: NWConnection
    private let queue: DispatchQueue
    private let completion: (CodexJournalReader) -> Void

    init(
        reader: CodexJournalReader, connection: NWConnection, queue: DispatchQueue,
        completion: @escaping (CodexJournalReader) -> Void
    ) {
        self.reader = reader
        self.connection = connection
        self.queue = queue
        self.completion = completion
    }

    func send() {
        if let batch = reader.nextBatch() {
            connection.send(
                content: batch,
                completion: .contentProcessed { error in
                    self.queue.async {
                        if error == nil { self.send() } else { self.connection.cancel() }
                    }
                })
        } else if reader.failed {
            connection.cancel()
        } else {
            completion(reader)
        }
    }

    static func resume(sessionId: String, afterSeq: Int, connection: NWConnection) -> Bool {
        if let journal = CodexJournal(sessionId: sessionId, reset: false),
            let reader = journal.reader(afterSeq: afterSeq)
        {
            let queue = DispatchQueue(label: "app.afto.codex.replay")
            queue.async {
                CodexJournalReplay(reader: reader, connection: connection, queue: queue) { reader in
                    var terminal = Data()
                    var events: [[String: Any]] = []
                    if reader.lastEvent["type"] as? String == "exit" {
                        if !reader.sentExit { events.append(reader.lastEvent) }
                    } else {
                        events = [
                            [
                                "type": "error",
                                "message":
                                    "The daemon restarted during this turn. Send a message to resume your saved Codex conversation.",
                                "seq": reader.lastSeq + 1, "sessionId": sessionId,
                            ],
                            ["type": "exit", "code": 1, "seq": reader.lastSeq + 2, "sessionId": sessionId],
                        ]
                    }
                    for event in events {
                        if let data = try? JSONSerialization.data(withJSONObject: event) {
                            terminal.append(data)
                            terminal.append(0x0A)
                        }
                    }
                    connection.send(
                        content: terminal, isComplete: true, completion: .contentProcessed { _ in connection.cancel() })
                }.send()
            }
            return true
        }
        return false
    }
}
