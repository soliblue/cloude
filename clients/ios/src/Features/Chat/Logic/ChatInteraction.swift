import Foundation

nonisolated struct ChatInteraction: Identifiable, Equatable {
    let id: String
    let method: String
    let paramsJSON: String

    var params: [String: Any] {
        (try? JSONSerialization.jsonObject(with: Data(paramsJSON.utf8)) as? [String: Any]) ?? [:]
    }

    var title: String {
        method.contains("requestUserInput") || method == "mcpServer/elicitation/request"
            ? "Information requested" : "Approval needed"
    }

    var detail: String {
        var lines = ["message", "reason", "command", "cwd"].compactMap { params[$0] as? String }.filter { !$0.isEmpty }
        if let permissions = params["permissions"] { lines.append(ChatToolCall.prettyJSON(permissions)) }
        return lines.isEmpty ? "Review this action before the agent continues." : lines.joined(separator: "\n\n")
    }

    func approvalResult(_ decision: String) -> [String: Any] {
        if method == "item/permissions/requestApproval" {
            return [
                "permissions": decision == "accept" || decision == "acceptForSession"
                    ? params["permissions"] ?? [:] : [:], "scope": decision == "acceptForSession" ? "session" : "turn",
            ]
        }
        if method == "mcpServer/elicitation/request" {
            return ["action": decision == "accept" || decision == "acceptForSession" ? "accept" : "decline"]
        }
        if method == "execCommandApproval" || method == "applyPatchApproval" {
            if decision == "decline" { return ["decision": ["denied": ["rejection": "Declined from Afto"]]] }
            return [
                "decision": decision == "accept"
                    ? "approved" : decision == "acceptForSession" ? "approved_for_session" : "abort"
            ]
        }
        return ["decision": decision]
    }

    func answersResult(_ answers: [String: String]) -> [String: Any] {
        if method == "mcpServer/elicitation/request" {
            var content: [String: Any] = [:]
            for question in questions {
                let answer = answers[question.id] ?? question.defaultValue
                if !answer.isEmpty || question.isRequired { content[question.id] = question.value(answer) }
            }
            return ["action": "accept", "content": content]
        }
        return ["answers": answers.mapValues { ["answers": [$0]] }]
    }

    var questions: [ChatInteractionQuestion] {
        if let schema = params["requestedSchema"] as? [String: Any],
            let properties = schema["properties"] as? [String: [String: Any]]
        {
            return properties.keys.sorted().map { id in
                let field = properties[id] ?? [:]
                let type = field["type"] as? String ?? "string"
                return ChatInteractionQuestion(
                    id: id, question: field["title"] as? String ?? field["description"] as? String ?? id,
                    options: field["enum"] as? [String] ?? [], isSecret: field["format"] as? String == "password",
                    valueType: type, isRequired: (schema["required"] as? [String] ?? []).contains(id),
                    defaultValue: type == "boolean"
                        ? String(field["default"] as? Bool ?? false)
                        : field["default"].map { String(describing: $0) } ?? "",
                    allowsCustomAnswer: false)
            }
        }
        return ((params["questions"] as? [[String: Any]]) ?? []).compactMap { item in
            if let id = item["id"] as? String, let question = item["question"] as? String {
                return ChatInteractionQuestion(
                    id: id, question: question,
                    options: ((item["options"] as? [[String: Any]]) ?? []).compactMap { $0["label"] as? String },
                    isSecret: item["isSecret"] as? Bool ?? false,
                    optionDescriptions: Dictionary(
                        ((item["options"] as? [[String: Any]]) ?? []).compactMap { option in
                            if let label = option["label"] as? String,
                                let description = option["description"] as? String
                            {
                                return (label, description)
                            }
                            return nil
                        }, uniquingKeysWith: { first, _ in first }))
            }
            return nil
        }
    }
}
