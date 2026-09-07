import Foundation

enum CodexHandler {
    static func isMutating(_ sessionId: String) -> Bool { false }
    static func perform(_ method: String, params: [String: Any]) -> [String: Any]? { nil }
}
