import CryptoKit
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
        if let data = try? JSONEncoder().encode(next) { return CodexPersistence.write(data, to: url) }
        return false
    }
}
