import Foundation
import SwiftData

@Model
final class ChatToolCall {
    enum State: String { case pending, succeeded, failed }

    @Attribute(.unique) var id: String
    var messageId: UUID
    var sessionId: UUID
    var name: String
    var inputSummary: String
    var inputJSON: String
    var result: String?
    var stateRaw: String
    var order: Int
    var parentToolUseId: String?
    @Transient var cachedInput: [String: Any]?
    @Transient var cachedResultText: String?
    @Transient var cachedResultValue: Any?

    init(
        id: String,
        messageId: UUID,
        sessionId: UUID,
        name: String,
        inputSummary: String,
        inputJSON: String,
        result: String? = nil,
        state: State = .pending,
        order: Int = 0,
        parentToolUseId: String? = nil
    ) {
        self.id = id
        self.messageId = messageId
        self.sessionId = sessionId
        self.name = name
        self.inputSummary = inputSummary
        self.inputJSON = inputJSON
        self.result = result
        self.stateRaw = state.rawValue
        self.order = order
        self.parentToolUseId = parentToolUseId
    }

    var state: State {
        get { State(rawValue: stateRaw) ?? .pending }
        set { stateRaw = newValue.rawValue }
    }

    var kind: ChatToolKind { ChatToolKind(name: name) }
    var symbol: String {
        if kind == .bash, let parsed = ChatBashCommand.parse(inputSummary) { return parsed.symbol }
        return kind.symbol
    }
    var displayName: String {
        if kind == .image { return "Image generation" }
        if kind == .task, let subagent = parsedInput["subagent_type"] as? String, !subagent.isEmpty {
            return subagent
        }
        if kind == .skill, let skill = parsedInput["skill"] as? String, !skill.isEmpty {
            return skill
        }
        if kind == .bash, let parsed = ChatBashCommand.parse(inputSummary) { return parsed.label }
        return name
    }

    var shortLabel: String {
        if kind == .image {
            return state == .pending ? "Generating image" : state == .failed ? "Image failed" : "Generated image"
        }
        if kind == .task {
            let label = ChatAgentActivity.label(parsedInput.merging(parsedResult) { _, result in result })
            return label.count > 32 ? String(label.prefix(32)) + "…" : label
        }
        if kind == .skill { return displayName }
        if kind == .edit, !fileChanges.isEmpty {
            return fileChanges.count == 1
                ? (fileChanges[0].path as NSString).lastPathComponent : "\(fileChanges.count) files"
        }
        let trimmed = inputSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return name }
        switch kind {
        case .read, .write, .edit:
            return (trimmed as NSString).lastPathComponent
        case .bash:
            if let parsed = ChatBashCommand.parse(trimmed) { return parsed.label }
            let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
            return firstLine.components(separatedBy: " ").first ?? firstLine
        default:
            return trimmed.count > 24 ? String(trimmed.prefix(24)) + "…" : trimmed
        }
    }

    nonisolated static func summarize(name: String, input: [String: Any]) -> String {
        if ChatToolKind(name: name) == .image { return "Image generation" }
        if ChatToolKind(name: name) == .task { return ChatAgentActivity.label(input) }
        let keys = ["command", "file_path", "path", "pattern", "query", "url", "description"]
        for key in keys {
            if let value = input[key] as? String, !value.isEmpty { return value }
        }
        if let first = input.first, let string = first.value as? String { return string }
        return name
    }

    var webSources: [ChatWebSource] {
        var seen: Set<String> = []
        return (ChatWebSource.collect(parsedInput) + ChatWebSource.collect(parsedResult)).filter {
            seen.insert($0.id).inserted
        }
    }

    var parsedResult: [String: Any] {
        decodedResult as? [String: Any] ?? [:]
    }

    var decodedResult: Any? {
        if cachedResultText != result {
            cachedResultText = result
            cachedResultValue = result.flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) }
        }
        return cachedResultValue
    }

    var fileChanges: [ChatFileChange] {
        (decodedResult as? [[String: Any]] ?? parsedResult["changes"] as? [[String: Any]]
            ?? parsedInput["changes"] as? [[String: Any]] ?? []).compactMap(ChatFileChange.init)
    }

    var agentActivities: [ChatAgentActivity] {
        ChatAgentActivity.collect(input: parsedInput, result: parsedResult)
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
        let list =
            (parsedInput["todos"] as? [[String: Any]]) ?? (parsedInput["items"] as? [[String: Any]])
            ?? (parsedInput["plan"] as? [[String: Any]])
        return list?.map {
            ChatTodoItem(
                content: $0["content"] as? String ?? $0["step"] as? String ?? "",
                status: ChatTodoItem.Status(rawValue: $0["status"] as? String ?? "pending") ?? .pending
            )
        }
    }

    var showsDiff: Bool {
        guard state != .failed, kind == .bash else { return false }
        return ChatBashCommand.subcommand(inputSummary) == "diff"
    }

    var editStrings: (old: String, new: String)? {
        let old = parsedInput["old_string"] as? String
        let new = parsedInput["new_string"] as? String
        if let old, let new { return (old, new) }
        return nil
    }

    var editPairs: [(old: String, new: String)] {
        if let edit = editStrings { return [edit] }
        var pairs: [(old: String, new: String)] = []
        for edit in (parsedInput["edits"] as? [[String: Any]]) ?? [] {
            if let old = edit["old_string"] as? String, let new = edit["new_string"] as? String {
                pairs.append((old, new))
            }
        }
        return pairs
    }

    nonisolated static func prettyJSON(_ object: Any) -> String {
        if let data = try? JSONSerialization.data(
            withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
            let string = String(data: data, encoding: .utf8)
        {
            return string
        }
        return "\(object)"
    }
}
