import SwiftUI
import CloudeShared

struct ToolDetailSheet: View {
    let toolCall: ToolCall
    var children: [ToolCall] = []
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @State var outputExpanded = false

    private let outputPreviewLineCount = 15

    var chainedCommands: [ChainedCommand] {
        guard toolCall.name == "Bash", let input = toolCall.input else { return [] }
        return BashCommandParser.chainedCommandsWithOperators(for: input)
    }

    private var displayName: String {
        if toolCall.isMemoryCommand { return "Memory" }
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

    private var iconName: String {
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

    private var displayedOutput: String? {
        guard let lines = outputLines else { return nil }
        if outputExpanded || !outputNeedsTruncation {
            return lines.joined(separator: "\n")
        }
        return lines.prefix(outputPreviewLineCount).joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statusBanner

                    if let todos = todoItems {
                        todoSection(todos)
                    } else if !chainedCommands.isEmpty {
                        chainSection
                    } else if let input = toolCall.input, !input.isEmpty {
                        inputSection(input)
                    }

                    if let path = toolCall.filePath {
                        fileSection(path)
                    }

                    if let output = displayedOutput {
                        outputSection(output)
                    }

                    if !children.isEmpty {
                        childrenSection
                    }
                }
                .padding()
            }
            .background(Color.oceanBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 5) {
                        Image(systemName: iconName)
                            .font(.system(size: 12, weight: .semibold))
                        Text(displayName)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .lineLimit(1)
                    }
                    .foregroundColor(toolCallColor(for: toolCall.name, input: toolCall.input))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(toolCallColor(for: toolCall.name, input: toolCall.input).opacity(0.12))
                    .clipShape(Capsule())
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.oceanBackground)
    }

    @ViewBuilder
    private var statusBanner: some View {
        if toolCall.state == .executing {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Executing")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.oceanGray6.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
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
        case "completed": return .green
        case "in_progress": return .mint
        default: return .secondary
        }
    }
}
