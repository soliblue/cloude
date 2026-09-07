import CryptoKit
import Darwin
import Foundation

final class CodexSteerReceiptStore {
    static let shared = CodexSteerReceiptStore()
    private let url: URL
    private let queue = DispatchQueue(label: "app.afto.codex.steer-receipts")
    private var values: [String: [String: String]] = [:]
    private var writable = true
    var available: Bool { queue.sync { writable } }

    init(url: URL = CodexSessionStore.directory.appendingPathComponent("codex-steer-receipts.json")) {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url),
                let decoded = try? JSONDecoder().decode([String: [String: String]].self, from: data),
                decoded.values.allSatisfy({
                    $0["hash"]?.count == 64 && ["pending", "accepted"].contains($0["status"] ?? "")
                })
            {
                for (key, value) in decoded {
                    if let existing = values[key.lowercased()], existing != value { writable = false }
                    values[key.lowercased()] = value
                }
            } else {
                writable = false
            }
        }
    }

    func value(sessionId: String, requestId: String) -> [String: String]? {
        queue.sync {
            writable ? values[sessionId.lowercased() + ":" + requestId.lowercased()] : ["status": "unavailable"]
        }
    }

    func status(sessionId: String, requestId: String, prompt: String) -> String? {
        queue.sync {
            if !writable { return "unavailable" }
            if let value = values[sessionId.lowercased() + ":" + requestId.lowercased()] {
                return value["hash"]
                    == Data(SHA256.hash(data: Data(prompt.utf8))).map { String(format: "%02x", $0) }.joined()
                    ? value["status"] : "mismatch"
            }
            return nil
        }
    }

    func save(sessionId: String, requestId: String, hash: String, status: String) -> Bool {
        queue.sync {
            if writable {
                var next = values
                next[sessionId.lowercased() + ":" + requestId.lowercased()] = ["hash": hash, "status": status]
                if persist(next) {
                    values = next
                    return true
                }
                writable = false
            }
            return false
        }
    }

    private func persist(_ next: [String: [String: String]]) -> Bool {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        if let data = try? JSONEncoder().encode(next), (try? data.write(to: url, options: .atomic)) != nil,
            (try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)) != nil
        {
            let descriptor = Darwin.open(url.path, O_RDONLY)
            if descriptor >= 0 {
                let synced = Darwin.fsync(descriptor) == 0
                Darwin.close(descriptor)
                if synced {
                    let directory = Darwin.open(url.deletingLastPathComponent().path, O_RDONLY)
                    if directory >= 0 {
                        let syncedDirectory = Darwin.fsync(directory) == 0
                        Darwin.close(directory)
                        return syncedDirectory
                    }
                }
            }
        }
        return false
    }
}
