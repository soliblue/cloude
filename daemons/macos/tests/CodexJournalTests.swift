import Foundation

@main
struct CodexJournalTests {
    static func main() throws {
        let sessionId = UUID().uuidString
        let journal = CodexJournal(sessionId: sessionId, reset: true)!
        var expected = Data()
        for seq in 1...12_000 {
            var data = try JSONSerialization.data(withJSONObject: [
                "seq": seq, "sessionId": sessionId, "text": "Unicode 🦉 café \(seq)",
            ])
            data.append(0x0A)
            precondition(journal.append(data, seq: seq))
            if seq > 999 { expected.append(data) }
        }
        let snapshot = journal.reader(afterSeq: 999)!
        let late = Data("{\"seq\":12001,\"type\":\"exit\",\"code\":0}\n".utf8)
        precondition(journal.append(late, seq: 12_001))
        var actual = Data()
        while let batch = snapshot.nextBatch() {
            actual.append(batch)
            precondition(batch.count < 66_000)
        }
        precondition(actual == expected && snapshot.lastSeq == 12_000 && !snapshot.failed && !snapshot.sentExit)
        let tail = journal.reader(afterSeq: 12_000)!
        precondition(tail.nextBatch() == late && tail.nextBatch() == nil && tail.sentExit)
        let restored = CodexJournal(sessionId: sessionId, reset: false)!.reader(afterSeq: 12_000)!
        precondition(restored.nextBatch() == late && !restored.failed)
        let fullySeen = journal.reader(afterSeq: 12_001)!
        precondition(
            fullySeen.nextBatch() == nil && fullySeen.lastEvent["type"] as? String == "exit" && !fullySeen.sentExit)
        let oldReader = journal.reader(afterSeq: 12_000)!
        let replacement = CodexJournal(sessionId: sessionId, reset: true)!
        precondition(replacement.length == 0 && oldReader.nextBatch() == late)
        precondition(journal.reader(afterSeq: 12_000)!.nextBatch() == late)
        precondition(
            CodexJournal.url(sessionId: "../../unsafe").deletingLastPathComponent()
                == CodexJournal.url(sessionId: sessionId).deletingLastPathComponent())
        precondition(
            CodexJournal.url(sessionId: sessionId.uppercased()) == CodexJournal.url(sessionId: sessionId.lowercased()))
        for payload in ["{bad}\n", "{\"seq\":1}", "\n"] {
            precondition(replacement.append(Data(payload.utf8), seq: 1))
            let corrupt = replacement.reader(afterSeq: -1)!
            precondition(corrupt.nextBatch() == nil && corrupt.failed)
        }
        print(
            "Codex journal: 12,000 events, exact suffix replay, bounded batches, snapshots, restart, turn replacement and malformed input passed"
        )
    }
}
