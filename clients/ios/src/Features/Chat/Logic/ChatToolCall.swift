import Foundation
import SwiftData

@Model
final class ChatToolCall {
    enum State: String { case pending, succeeded, failed }

    @Attribute(.unique) var id: String
    var message: ChatMessage?
    var name: String
    var inputSummary: String
    var inputJSON: String
    var result: String?
    var stateRaw: String
    var order: Int
    @Transient private var cachedInput: [String: Any]?

    init(
        id: String,
        name: String,
        inputSummary: String,
        inputJSON: String,
        result: String? = nil,
        state: State = .pending,
        order: Int = 0
    ) {
        self.id = id
        self.name = name
        self.inputSummary = inputSummary
        self.inputJSON = inputJSON
        self.result = result
        self.stateRaw = state.rawValue
        self.order = order
    }

    var state: State {
        get { State(rawValue: stateRaw) ?? .pending }
        set { stateRaw = newValue.rawValue }
    }

    var kind: ChatToolKind { ChatToolKind(name: name) }
    var symbol: String { kind.symbol }

    var shortLabel: String {
        let trimmed = inputSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return name }
        switch kind {
        case .read, .write, .edit:
            return (trimmed as NSString).lastPathComponent
        case .bash:
            let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
            return firstLine.components(separatedBy: " ").first ?? firstLine
        default:
            return trimmed.count > 24 ? String(trimmed.prefix(24)) + "…" : trimmed
        }
    }

    static func summarize(name: String, input: [String: Any]) -> String {
        let keys = ["command", "file_path", "path", "pattern", "query", "url", "description"]
        for key in keys {
            if let value = input[key] as? String, !value.isEmpty { return value }
        }
        if let first = input.first, let string = first.value as? String { return string }
        return name
    }

    var filePath: String? {
        parsedInput["file_path"] as? String ?? parsedInput["path"] as? String
    }

    var parsedInput: [String: Any] {
        if let cached = cachedInput { return cached }
        let decoded =
            (try? JSONSerialization.jsonObject(with: Data(inputJSON.utf8)) as? [String: Any]) ?? [:]
        cachedInput = decoded
        return decoded
    }

    var todoItems: [ChatTodoItem]? {
        if case .todo = kind {} else { return nil }
        let list = (parsedInput["todos"] as? [[String: Any]]) ?? (parsedInput["items"] as? [[String: Any]])
        return list?.map {
            ChatTodoItem(
                content: $0["content"] as? String ?? "",
                status: ChatTodoItem.Status(rawValue: $0["status"] as? String ?? "pending") ?? .pending
            )
        }
    }

    var editStrings: (old: String, new: String)? {
        let old = parsedInput["old_string"] as? String
        let new = parsedInput["new_string"] as? String
        if let old, let new { return (old, new) }
        return nil
    }

    static func prettyJSON(_ object: Any) -> String {
        if let data = try? JSONSerialization.data(
            withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
            let string = String(data: data, encoding: .utf8)
        {
            return string
        }
        return "\(object)"
    }
}
