import Darwin
import Foundation

final class CodexJournalReader {
    private let handle: FileHandle
    private let length: UInt64
    private var offset: UInt64 = 0
    private var buffer = Data()
    private var consumed = 0
    private(set) var lastSeq: Int
    private(set) var lastEvent: [String: Any] = [:]
    private(set) var failed = false
    private(set) var sentExit = false

    init(handle: FileHandle, length: UInt64, afterSeq: Int) {
        self.handle = handle
        self.length = length
        lastSeq = afterSeq
    }

    func nextBatch() -> Data? {
        var batch = Data()
        while batch.count < 65_536, !failed {
            if let newline = buffer[consumed...].firstIndex(of: 0x0A) {
                let line = buffer.subdata(in: consumed..<newline)
                consumed = newline + 1
                if let event = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                    let seq = event["seq"] as? Int
                {
                    lastEvent = event
                    if seq > lastSeq {
                        batch.append(line)
                        batch.append(0x0A)
                        lastSeq = seq
                        if event["type"] as? String == "exit" { sentExit = true }
                    }
                } else {
                    failed = true
                }
            } else if offset < length {
                buffer = Data(buffer[consumed...])
                consumed = 0
                var bytes = [UInt8](repeating: 0, count: Int(min(65_536, length - offset)))
                let count = pread(handle.fileDescriptor, &bytes, bytes.count, off_t(offset))
                if count > 0, buffer.count + count <= 32 * 1024 * 1024 {
                    offset += UInt64(count)
                    buffer.append(contentsOf: bytes.prefix(count))
                } else {
                    failed = true
                }
            } else {
                if consumed != buffer.count { failed = true }
                break
            }
        }
        return batch.isEmpty ? nil : batch
    }
}
