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
            if name.hasPrefix("mcp__"), let input = input,
               let data = try? JSONSerialization.data(withJSONObject: input),
               let json = String(data: data, encoding: .utf8) {
                return json
            }
            return nil
        }
    }

    public static func extractEditInfo(input: [String: Any]?) -> EditInfo? {
        guard let input,
              let oldString = input["old_string"] as? String,
              let newString = input["new_string"] as? String else { return nil }
        return EditInfo(oldString: oldString, newString: newString)
    }
}
