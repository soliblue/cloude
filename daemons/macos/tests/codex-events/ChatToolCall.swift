import Foundation

nonisolated enum ChatToolCall {
    static func summarize(name: String, input: [String: Any]) -> String { name }
    static func prettyJSON(_ object: Any) -> String {
        String(
            data: try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .fragmentsAllowed]),
            encoding: .utf8)!
    }
}
