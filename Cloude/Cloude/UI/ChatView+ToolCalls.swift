import SwiftUI

struct ToolCallsSection: View {
    let toolCalls: [ToolCall]
    @State private var expandedToolId: String?

    private var topLevelCalls: [ToolCall] {
        Array(toolCalls.filter { $0.parentToolId == nil }.reversed())
    }

    private func children(of toolId: String) -> [ToolCall] {
        toolCalls.filter { $0.parentToolId == toolId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(topLevelCalls, id: \.toolId) { toolCall in
                        ToolPill(
                            toolCall: toolCall,
                            childCount: children(of: toolCall.toolId).count,
                            isExpanded: expandedToolId == toolCall.toolId
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .opacity
                        ))
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if expandedToolId == toolCall.toolId {
                                    expandedToolId = nil
                                } else if !children(of: toolCall.toolId).isEmpty {
                                    expandedToolId = toolCall.toolId
                                }
                            }
                        }
                    }
                }
                .animation(.easeOut(duration: 0.25), value: topLevelCalls.count)
            }

            if let expandedId = expandedToolId {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(children(of: expandedId).enumerated()), id: \.offset) { _, child in
                        ToolCallRow(name: child.name, input: child.input)
                    }
                }
                .padding(.leading, 8)
                .transition(.opacity)
            }
        }
    }
}

struct ToolPill: View {
    let toolCall: ToolCall
    let childCount: Int
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .semibold))
            Text(toolCall.name)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
            if let detail = displayDetail {
                Text(detail)
                    .font(.system(size: 12, design: .monospaced))
                    .opacity(0.85)
            }
            if childCount > 0 {
                Text("(\(childCount))")
                    .font(.system(size: 10))
                    .opacity(0.7)
            }
        }
        .lineLimit(1)
        .foregroundColor(toolColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(toolColor.opacity(isExpanded ? 0.2 : 0.12))
        .cornerRadius(14)
    }

    private var displayDetail: String? {
        guard let input = toolCall.input, !input.isEmpty else {
            return nil
        }

        switch toolCall.name {
        case "Read", "Write", "Edit":
            let filename = (input as NSString).lastPathComponent
            return truncateFilename(filename, maxLength: 16)
        case "Bash":
            let truncated = input.prefix(20)
            return truncated.count < input.count ? "\(truncated)..." : String(input)
        case "Glob", "Grep":
            let truncated = input.prefix(16)
            return truncated.count < input.count ? "\(truncated)..." : String(input)
        case "Task":
            let parts = input.split(separator: ":", maxSplits: 1)
            return parts.first.map(String.init)
        default:
            return nil
        }
    }

    private func truncateFilename(_ filename: String, maxLength: Int) -> String {
        guard filename.count > maxLength else { return filename }
        let ext = (filename as NSString).pathExtension
        let name = (filename as NSString).deletingPathExtension
        let availableLength = maxLength - ext.count - (ext.isEmpty ? 0 : 4)
        guard availableLength > 0 else { return filename }
        return "\(name.prefix(availableLength))….\(ext)"
    }

    private var iconName: String {
        switch toolCall.name.lowercased() {
        case let n where n.contains("read"): return "doc.text"
        case let n where n.contains("write"), let n where n.contains("edit"): return "pencil"
        case let n where n.contains("bash"), let n where n.contains("shell"): return "terminal"
        case let n where n.contains("glob"), let n where n.contains("search"): return "magnifyingglass"
        case let n where n.contains("task"), let n where n.contains("agent"): return "person.2"
        default: return "wrench"
        }
    }

    private var toolColor: Color {
        toolCallColor(for: toolCall.name)
    }
}

func toolCallColor(for name: String) -> Color {
    switch name {
    case "Read": return .blue
    case "Write", "Edit": return .orange
    case "Bash": return .green
    case "Glob": return .purple
    case "Grep": return .pink
    case "Task": return .cyan
    case "WebFetch", "WebSearch": return .indigo
    case "TodoWrite": return .mint
    case "NotebookEdit": return .purple
    case "AskUserQuestion": return .orange
    default: return .secondary
    }
}
