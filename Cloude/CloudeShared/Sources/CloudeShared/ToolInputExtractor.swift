import Foundation

public enum ToolInputExtractor {
    public static func extract(name: String, input: [String: Any]?) -> String? {
        switch name {
        case "Bash":
            return input?["command"] as? String
        case "Read", "Write", "Edit":
            return input?["file_path"] as? String
        case "Glob":
            return input?["pattern"] as? String
        case "Grep":
            return input?["pattern"] as? String
        case "WebFetch":
            return input?["url"] as? String
        case "WebSearch":
            return input?["query"] as? String
        case "Task":
            let agentType = input?["subagent_type"] as? String ?? "agent"
            let description = input?["description"] as? String ?? ""
            return "\(agentType): \(description)"
        case "Skill":
            let skill = input?["skill"] as? String ?? ""
            let args = input?["args"] as? String
            if let args = args, !args.isEmpty {
                return "\(skill):\(args)"
            }
            return skill.nilIfEmpty
        case "TodoWrite":
            guard let todos = input?["todos"] as? [[String: Any]] else { return nil }
            if let data = try? JSONSerialization.data(withJSONObject: todos),
               let json = String(data: data, encoding: .utf8) {
                return json
            }
            return nil
        case "TeamCreate", "TeamDelete":
            return input?["team_name"] as? String
        case "SendMessage":
            let target = input?["target"] as? String ?? ""
            let msgType = input?["type"] as? String ?? "message"
            return "\(msgType) → \(target)"
        default:
            return nil
        }
    }

    public static func extractDisplayDetail(name: String, input: [String: Any]?) -> String? {
        guard let raw = extract(name: name, input: input) else { return nil }
        switch name {
        case "Bash":
            let firstLine = raw.components(separatedBy: .newlines).first ?? raw
            let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
            return truncate(trimmed, to: 40)
        case "Read", "Write", "Edit":
            return raw.lastPathComponent
        case "Grep":
            return truncate(raw, to: 30)
        case "Task":
            let description = input?["description"] as? String ?? ""
            return truncate(description, to: 60)
        default:
            return raw
        }
    }

    public static func extractDisplayDetail(name: String, jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return extractDisplayDetail(name: name, input: parsed)
    }

    private static func truncate(_ string: String, to limit: Int) -> String {
        if string.count > limit {
            return String(string.prefix(limit - 3)) + "..."
        }
        return string
    }
}
