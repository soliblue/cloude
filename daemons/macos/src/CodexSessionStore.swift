import Foundation

final class CodexSessionStore {
    static let shared = CodexSessionStore()
    private let url: URL
    private var values: [String: [String: String]] = [:]
    private var writable = true
    var available: Bool { queue.sync { writable } }
    private let queue = DispatchQueue(label: "app.afto.codex.sessions")

    static var directory: URL {
        ProcessInfo.processInfo.environment["CLOUDE_DATA"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cloude-agent")
    }

    init(url: URL = CodexSessionStore.directory.appendingPathComponent("codex-sessions.json")) {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url),
                let decoded = try? JSONDecoder().decode([String: [String: String]].self, from: data),
                decoded.values.allSatisfy({ $0["threadId"]?.isEmpty == false && $0["path"]?.isEmpty == false })
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

    func threadId(for sessionId: String) -> String? { queue.sync { values[sessionId.lowercased()]?["threadId"] } }

    @discardableResult
    func save(sessionId: String, threadId: String, path: String) -> Bool {
        queue.sync {
            if writable {
                var next = values
                next[sessionId.lowercased()] = ["threadId": threadId, "path": path]
                if let data = try? JSONEncoder().encode(next), CodexPersistence.write(data, to: url) {
                    values = next
                    return true
                }
                writable = false
            }
            return false
        }
    }
}
