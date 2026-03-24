import SwiftUI
import CloudeShared

extension ToolDetailSheet {
    var childrenSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Tools (\(children.count))", systemImage: "square.stack")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(children.enumerated()), id: \.element.toolId) { index, child in
                    HStack(spacing: 10) {
                        ToolCallLabel(name: child.name, input: child.input)
                            .lineLimit(1)

                        Spacer()

                        if child.state == .executing {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.caption2.weight(.bold))
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
            .background(Color.themeGray6.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    func todoSection(_ todos: [[String: String]]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let completed = todos.filter { $0["status"] == "completed" }.count
            Label("\(completed)/\(todos.count) tasks", systemImage: "checklist")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(todos.enumerated()), id: \.offset) { index, todo in
                    HStack(spacing: 10) {
                        Image(systemName: todoStatusIcon(todo["status"] ?? "pending"))
                            .font(.footnote.weight(.medium))
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
            .background(Color.themeGray6.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    var chainSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Chained Commands", systemImage: "link")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(chainedCommands.enumerated()), id: \.offset) { index, chained in
                    VStack(spacing: 0) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: ToolCallLabel(name: "Bash", input: chained.command).iconName)
                                .font(.footnote.weight(.medium))
                                .foregroundColor(toolCallColor(for: "Bash", input: chained.command))
                                .frame(width: 20)
                                .padding(.top, 2)

                            Text(chained.command)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)

                        if let op = chained.operatorAfter {
                            HStack(spacing: 8) {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(width: 1, height: 16)
                                    .padding(.leading, 21)
                                Text(op.rawValue)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .background(Color.themeGray6.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
