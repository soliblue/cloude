import SwiftUI
import CloudeShared

extension ToolDetailSheet {
    var childrenSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Label("Tools (\(children.count))", systemImage: "square.stack")
                .font(.system(size: DS.Text.m, weight: .semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(children.enumerated()), id: \.element.toolId) { index, child in
                    HStack(spacing: DS.Spacing.m) {
                        ToolCallLabel(name: child.name, input: child.input)
                            .lineLimit(1)
                        Spacer()
                        if child.state == .executing {
                            ProgressView()
                                .scaleEffect(DS.Scale.s)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: DS.Text.s, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, DS.Spacing.s)
                    .padding(.horizontal, DS.Spacing.m)

                    if index < children.count - 1 {
                        Divider()
                            .padding(.leading, DS.Spacing.m)
                    }
                }
            }
            .background(Color.themeSecondary.opacity(DS.Opacity.m))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m))
        }
    }

    func todoSection(_ todos: [[String: String]]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            let completed = todos.filter { $0["status"] == "completed" }.count
            Label("\(completed)/\(todos.count) tasks", systemImage: "checklist")
                .font(.system(size: DS.Text.m, weight: .semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(todos.enumerated()), id: \.offset) { index, todo in
                    HStack(spacing: DS.Spacing.m) {
                        Image(systemName: todoStatusIcon(todo["status"] ?? "pending"))
                            .font(.system(size: DS.Text.m, weight: .medium))
                            .foregroundColor(todoStatusColor(todo["status"] ?? "pending"))
                        Text(todo["content"] ?? "")
                            .font(.system(size: DS.Text.m))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(todo["status"] == "completed" ? .secondary : .primary)
                    }
                    .padding(.vertical, DS.Spacing.s)
                    .padding(.horizontal, DS.Spacing.m)

                    if index < todos.count - 1 {
                        Divider()
                            .padding(.leading, DS.Spacing.l)
                    }
                }
            }
            .background(Color.themeSecondary.opacity(DS.Opacity.m))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m))
        }
    }

    var chainSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Label("Chained Commands", systemImage: "link")
                .font(.system(size: DS.Text.m, weight: .semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(meta.chainedCommands.enumerated()), id: \.offset) { _, chained in
                    let cmdMeta = ToolMetadata(name: "Bash", input: chained.command)
                    HStack(alignment: .center, spacing: DS.Spacing.m) {
                        Image(systemName: cmdMeta.icon)
                            .font(.system(size: DS.Text.m, weight: .medium))
                            .foregroundColor(cmdMeta.color)
                        Text(chained.command)
                            .font(.system(size: DS.Text.m, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, DS.Spacing.m)
                    .padding(.horizontal, DS.Spacing.m)
                }
            }
            .background(Color.themeSecondary.opacity(DS.Opacity.m))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m))
        }
    }
}
