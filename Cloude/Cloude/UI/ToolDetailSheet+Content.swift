import SwiftUI
import CloudeShared

extension ToolDetailSheet {
    func inputSection(_ input: String) -> some View {
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

    func outputSection(_ output: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Output", systemImage: "arrow.left.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                Text(output)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if outputNeedsTruncation {
                    Divider()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            outputExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(outputExpanded ? "Show less" : "Show all \(outputLines?.count ?? 0) lines")
                                .font(.subheadline.weight(.medium))
                            Image(systemName: outputExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                }
            }
            .background(Color.oceanGray6.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    func fileSection(_ path: String) -> some View {
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
                                .font(.system(size: 14, weight: .medium))
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
            .background(Color.oceanGray6.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
