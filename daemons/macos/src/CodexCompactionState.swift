import Foundation

struct CodexCompactionState {
    let operationId = UUID()
    let threadId: String
    var status = "pending"
    var started = false
    var turnId: String?
    var contextTokens: Int?
    var contextWindow: Int?
    var error: String?

    var json: [String: Any] {
        var value: [String: Any] = ["status": status, "threadId": threadId]
        if let contextTokens { value["contextTokens"] = contextTokens }
        if let contextWindow { value["contextWindow"] = contextWindow }
        if let error { value["error"] = error }
        return value
    }
}
