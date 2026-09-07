import Foundation

enum CodexHandler {
    static var mutating = false
    static func isMutating(_ sessionId: String) -> Bool { mutating }
    static func perform(_ method: String, params: [String: Any]) -> [String: Any]? { nil }
}
