final class CodexSessionStore {
    static let shared = CodexSessionStore()
    func threadId(for sessionId: String) -> String? { sessionId == "imported" ? "child-thread" : nil }
}
