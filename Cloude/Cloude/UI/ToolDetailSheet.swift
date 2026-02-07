import SwiftUI
import CloudeShared

struct ToolDetailSheet: View {
    let toolCall: ToolCall
    var children: [ToolCall] = []
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var isMemoryCommand: Bool {
        toolCall.name == "Bash" && (toolCall.input?.hasPrefix("cloude memory ") ?? false)
    }

    private var isScript: Bool {
        guard toolCall.name == "Bash", let input = toolCall.input else { return false }
        return BashCommandParser.isScript(input)
    }

    private var chainedCommands: [String] {
        guard toolCall.name == "Bash", let input = toolCall.input else { return [] }
        if isScript { return [] }
        let commands = BashCommandParser.splitChainedCommands(input)
        return commands.count > 1 ? commands : []
    }

    private var filePath: String? {
        guard let input = toolCall.input else { return nil }
        if ["Read", "Write", "Edit"].contains(toolCall.name) {
            return input
        }
        return nil
    }

    private var displayName: String {
        if isMemoryCommand { return "Memory" }
        if isScript { return "Script" }
        if toolCall.name == "Bash", let input = toolCall.input {
            let commands = BashCommandParser.splitChainedCommands(input)
            if commands.count > 1 {
                let names = commands.map { cmd -> String in
                    let parsed = BashCommandParser.parse(cmd)
                    return parsed.command.isEmpty ? "bash" : parsed.command
                }
                return names.joined(separator: " && ")
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

    private var todoItems: [[String: String]]? {
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let todos = todoItems {
                        todoSection(todos)
                    } else if !chainedCommands.isEmpty {
                        chainSection
                    } else if let input = toolCall.input, !input.isEmpty {
                        inputSection(input)
                    }

                    if let path = filePath {
                        fileSection(path)
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
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Image(systemName: iconName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(toolCallColor(for: toolCall.name, input: toolCall.input))
                        Text(displayName)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                    }
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
        .presentationBackground(.ultraThinMaterial)
    }

    private func inputSection(_ input: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Input", systemImage: "arrow.right.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            Text(input)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.oceanGray6.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func fileSection(_ path: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("File", systemImage: "doc")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            Button {
                if let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                   let url = URL(string: "cloude://file\(encodedPath)") {
                    openURL(url)
                    dismiss()
                }
            } label: {
                HStack {
                    Image(systemName: fileIconName(for: path.lastPathComponent))
                        .foregroundColor(fileIconColor(for: path.lastPathComponent))
                    Text(path.lastPathComponent)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.oceanGray6.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    private var childrenSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Tools (\(children.count))", systemImage: "square.stack")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(children.enumerated()), id: \.element.toolId) { index, child in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            ToolCallLabel(name: child.name, input: child.input, size: .small)
                                .lineLimit(1)

                            if let summary = child.resultSummary {
                                HStack(spacing: 3) {
                                    Text("↳")
                                        .font(.system(size: 10))
                                    Text(summary)
                                        .font(.system(size: 10, design: .monospaced))
                                        .lineLimit(1)
                                }
                                .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if child.state == .executing {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)

                    if index < children.count - 1 {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
            .background(Color.oceanGray6.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func todoSection(_ todos: [[String: String]]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let completed = todos.filter { $0["status"] == "completed" }.count
            Label("\(completed)/\(todos.count) tasks", systemImage: "checklist")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(todos.enumerated()), id: \.offset) { index, todo in
                    HStack(spacing: 10) {
                        Image(systemName: todoStatusIcon(todo["status"] ?? "pending"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(todoStatusColor(todo["status"] ?? "pending"))
                            .frame(width: 20)

                        Text(todo["content"] ?? "")
                            .font(.system(.body))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(todo["status"] == "completed" ? .secondary : .primary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)

                    if index < todos.count - 1 {
                        Divider()
                            .padding(.leading, 42)
                    }
                }
            }
            .background(Color.oceanGray6.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func todoStatusIcon(_ status: String) -> String {
        switch status {
        case "completed": return "checkmark.circle.fill"
        case "in_progress": return "circle.dotted.circle"
        default: return "circle"
        }
    }

    private func todoStatusColor(_ status: String) -> Color {
        switch status {
        case "completed": return .green
        case "in_progress": return .mint
        default: return .secondary
        }
    }

    private var chainSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Chained Commands", systemImage: "link")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(chainedCommands.enumerated()), id: \.offset) { index, cmd in
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Image(systemName: ToolCallLabel(name: "Bash", input: cmd).iconName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(toolCallColor(for: "Bash", input: cmd))
                                .frame(width: 20)

                            Text(cmd)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)

                        if index < chainedCommands.count - 1 {
                            HStack(spacing: 8) {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(width: 1, height: 16)
                                    .padding(.leading, 21)
                                Text("&&")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .background(Color.oceanGray6.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
