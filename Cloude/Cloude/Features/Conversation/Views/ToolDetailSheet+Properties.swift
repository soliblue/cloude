// ToolDetailSheet+Properties.swift

import SwiftUI
import CloudeShared

extension ToolDetailSheet {
    var chainedCommands: [ChainedCommand] {
        guard toolCall.name == "Bash", let input = toolCall.input else { return [] }
        return BashCommandParser.chainedCommandsWithOperators(for: input)
    }

    var toolTitle: String {
        if toolCall.name == "TodoWrite" { return "Tasks" }
        if toolCall.name == "Agent" { return "Agent" }
        if ToolCallLabel.isIOSControl(toolCall.name) { return "iOS" }
        if ToolCallLabel.isWhiteboardTool(toolCall.name) { return "Whiteboard" }
        if WidgetRegistry.isWidget(toolCall.name) { return "Widget" }
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
