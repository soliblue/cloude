import Foundation

final class CodexThreadStore {
    static let shared = CodexThreadStore()

    private var loaded = false
    private var values: [String: String] = [:]

    func threadId(sessionId: String) -> String? {
        load()
        return values[sessionId.lowercased()]
    }

    func set(threadId: String, sessionId: String) {
        load()
        values[sessionId.lowercased()] = threadId
        save()
    }

    private func load() {
        if loaded { return }
        loaded = true
        if let data = try? Data(contentsOf: url),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        {
            values = object
        }
    }

    private func save() {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted]) {
            try? data.write(to: url)
        }
    }

    private var url: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Remote CC", isDirectory: true)
            .appendingPathComponent("codex-threads.json")
    }
}
