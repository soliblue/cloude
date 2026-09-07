import CryptoKit
import Foundation

final class CodexForkReceiptStore {
    let directory: URL

    init(directory: URL = CodexSessionStore.directory.appendingPathComponent("codex-forks")) {
        self.directory = directory
    }

    func url(sessionId: String) -> URL {
        directory.appendingPathComponent(
            SHA256.hash(data: Data(sessionId.lowercased().utf8)).map { String(format: "%02x", $0) }.joined() + ".json")
    }

    func value(sessionId: String) -> [String: Any]? {
        let url = url(sessionId: sessionId)
        if FileManager.default.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url),
                let value = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                (value["hash"] as? String)?.count == 64,
                value["status"] as? String == "pending"
                    || value["status"] as? String == "completed" && value["response"] is [String: Any]
            {
                return value
            }
            return ["status": "unavailable"]
        }
        return nil
    }

    func save(sessionId: String, hash: String, response: [String: Any]? = nil) -> Bool {
        var value: [String: Any] = ["hash": hash, "status": response == nil ? "pending" : "completed"]
        if let response { value["response"] = response }
        if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) {
            return CodexPersistence.write(data, to: url(sessionId: sessionId), exclusive: response == nil)
        }
        return false
    }
}
