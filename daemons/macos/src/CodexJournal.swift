import CryptoKit
import Darwin
import Foundation

final class CodexJournal {
    private let handle: FileHandle
    private(set) var length: UInt64
    private(set) var lastSeq = -1

    static func url(sessionId: String) -> URL {
        CodexSessionStore.directory.appendingPathComponent("codex-journals")
            .appendingPathComponent(
                SHA256.hash(data: Data(sessionId.lowercased().utf8)).map { String(format: "%02x", $0) }.joined()
                    + ".jsonl")
    }

    init?(sessionId: String, reset: Bool) {
        let url = Self.url(sessionId: sessionId)
        if reset {
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            if (try? Data().write(to: url, options: .atomic)) == nil { return nil }
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
        if let handle = try? FileHandle(forUpdating: url), let size = try? handle.seekToEnd() {
            self.handle = handle
            length = size
        } else {
            return nil
        }
    }

    deinit { try? handle.close() }

    func append(_ data: Data, seq: Int) -> Bool {
        if (try? handle.write(contentsOf: data)) != nil {
            length += UInt64(data.count)
            lastSeq = seq
            return true
        }
        return false
    }

    func reader(afterSeq: Int) -> CodexJournalReader? {
        let descriptor = dup(handle.fileDescriptor)
        return descriptor >= 0
            ? CodexJournalReader(
                handle: FileHandle(fileDescriptor: descriptor, closeOnDealloc: true), length: length, afterSeq: afterSeq
            ) : nil
    }
}
