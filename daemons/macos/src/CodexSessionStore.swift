import Foundation

final class CodexSessionStore {
    static let shared = CodexSessionStore()
    private let url: URL
    private var values: [String: [String: String]]
    private let queue = DispatchQueue(label: "app.afto.codex.sessions")

    static var directory: URL {
        ProcessInfo.processInfo.environment["CLOUDE_DATA"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cloude-agent")
    }

    private init() {
        url = Self.directory.appendingPathComponent("codex-sessions.json")
        values =
            (try? Data(contentsOf: url)).flatMap {
                try? JSONDecoder().decode([String: [String: String]].self, from: $0)
            } ?? [:]
    }

    func threadId(for sessionId: String) -> String? { queue.sync { values[sessionId.lowercased()]?["threadId"] } }

    func save(sessionId: String, threadId: String, path: String) {
        queue.sync {
            values[sessionId.lowercased()] = ["threadId": threadId, "path": path]
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            if let data = try? JSONEncoder().encode(values) {
                try? data.write(to: url, options: .atomic)
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            }
        }
    }
}
