import SwiftUI
import CloudeShared

struct ToolDetailSheet: View {
    let toolCall: ToolCall
    var children: [ToolCall] = []
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @State var outputExpanded = false

    let outputPreviewLineCount = 15
    var meta: ToolMetadata { ToolMetadata(name: toolCall.name, input: toolCall.input) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.l) {
                    statusBanner

                    if let todos = todoItems {
                        todoSection(todos)
                    } else if !meta.chainedCommands.isEmpty {
                        chainSection
                    } else if let input = toolCall.input, !input.isEmpty,
                              toolCall.editInfo == nil {
                        inputSection(input)
                    }

                    if let path = toolCall.filePath {
                        fileSection(path)
                    }

                    if let editInfo = toolCall.editInfo {
                        editDiffSection(editInfo)
                    } else if toolCall.name == "Read", let output = toolCall.resultOutput, !output.isEmpty {
                        readOutputSection(output)
                    } else if toolCall.name == "Agent", let output = toolCall.resultOutput, !output.isEmpty {
                        markdownOutputSection(output)
                    } else if let output = displayedOutput {
                        outputSection(output)
                    }

                    if !children.isEmpty {
                        childrenSection
                    }
                }
                .padding()
            }
            .background(Color.themeBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: meta.chainedCommands.isEmpty ? meta.icon : "link")
                            .font(.system(size: DS.Text.m, weight: .semibold))
                        Text(meta.sheetTitle)
                            .font(.system(size: DS.Text.m, weight: .semibold, design: .monospaced))
                            .lineLimit(1)
                    }
                    .foregroundColor(meta.color)
                    .padding(.horizontal, DS.Spacing.m)
                    .padding(.vertical, DS.Spacing.s)
                    .background(meta.color.opacity(DS.Opacity.s))
                    .clipShape(Capsule())
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: DS.Icon.s, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.themeBackground)
    }

    @ViewBuilder
    var statusBanner: some View {
        if toolCall.state == .executing {
            HStack(spacing: DS.Spacing.s) {
                ProgressView()
                    .scaleEffect(DS.Scale.m)
                Text("Executing")
                    .font(.system(size: DS.Text.m, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(DS.Spacing.m)
            .background(Color.themeSecondary.opacity(DS.Opacity.m))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m))
        }
    }

    var todoItems: [[String: String]]? {
        guard toolCall.name == "TodoWrite",
              let input = toolCall.input,
              let data = input.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        return items.map { [
            "content": $0["content"] as? String ?? "",
            "status": $0["status"] as? String ?? "pending"
        ] }
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
        if outputExpanded || !outputNeedsTruncation { return lines.joined(separator: "\n") }
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
