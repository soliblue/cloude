// ToolDetailSheet+Properties.swift

import SwiftUI
import CloudeShared

extension ToolDetailSheet {
    var chainedCommands: [ChainedCommand] {
        guard toolCall.name == "Bash", let input = toolCall.input else { return [] }
        return BashCommandParser.chainedCommandsWithOperators(for: input)
    }

    var displayName: String {
        if toolCall.isScript { return "Script" }
        if toolCall.name == "Bash", let input = toolCall.input {
            let chained = BashCommandParser.chainedCommandsWithOperators(for: input)
            if chained.count > 1 {
                var parts: [String] = []
                for (i, cmd) in chained.enumerated() {
                    let parsed = BashCommandParser.parse(cmd.command)
                    parts.append(parsed.command.isEmpty ? "bash" : parsed.command)
                    if i < chained.count - 1, let op = cmd.operatorAfter {
                        parts.append(op.rawValue)
                    }
                }
                return parts.joined(separator: " ")
            }
            let parsed = BashCommandParser.parse(input)
            if !parsed.command.isEmpty {
                if let sub = parsed.subcommand {
                    return "\(parsed.command) \(sub)"
                }
                return parsed.command
            }
        }
        if toolCall.name == "TodoWrite" { return "Tasks" }
        return toolCall.name
    }

    var todoItems: [[String: String]]? {
        guard toolCall.name == "TodoWrite",
              let input = toolCall.input,
              let data = input.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        return items.map { item in
            [
                "content": item["content"] as? String ?? "",
                "status": item["status"] as? String ?? "pending"
            ]
        }
    }

    var iconName: String {
        if !chainedCommands.isEmpty {
            return "link"
        }
        return ToolCallLabel(name: toolCall.name, input: toolCall.input).iconName
    }

    var outputLines: [String]? {
        guard let output = toolCall.resultOutput, !output.isEmpty else { return nil }
        return output.components(separatedBy: "\n")
    }

    var outputNeedsTruncation: Bool {
        guard let lines = outputLines else { return false }
        return lines.count > outputPreviewLineCount
    }

    var displayedOutput: String? {
        guard let lines = outputLines else { return nil }
        if outputExpanded || !outputNeedsTruncation {
            return lines.joined(separator: "\n")
        }
        return lines.prefix(outputPreviewLineCount).joined(separator: "\n")
    }

    func todoStatusIcon(_ status: String) -> String {
        switch status {
        case "completed": return "checkmark.circle.fill"
        case "in_progress": return "circle.dotted.circle"
        default: return "circle"
        }
    }

    func todoStatusColor(_ status: String) -> Color {
        switch status {
        case "completed": return .pastelGreen
        case "in_progress": return .mint
        default: return .secondary
        }
    }
}
