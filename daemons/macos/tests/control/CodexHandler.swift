import Foundation

enum CodexHandler {
    static var calls: [(String, [String: Any])] = []
    static var handler: (String, [String: Any]) -> [String: Any]? = { _, _ in nil }
    static func perform(_ method: String, params: [String: Any]) -> [String: Any]? {
        calls.append((method, params))
        return handler(method, params)
    }
}
