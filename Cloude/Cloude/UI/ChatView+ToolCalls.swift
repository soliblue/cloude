import SwiftUI

struct ToolCallsSection: View {
    let toolCalls: [ToolCall]
    @State private var expandedToolId: String?

    private var topLevelCalls: [ToolCall] {
        toolCalls.filter { $0.parentToolId == nil }
    }

    private func children(of toolId: String) -> [ToolCall] {
        toolCalls.filter { $0.parentToolId == toolId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(topLevelCalls.enumerated()), id: \.offset) { _, toolCall in
                        ToolPill(
                            toolCall: toolCall,
                            childCount: children(of: toolCall.toolId).count,
                            isExpanded: expandedToolId == toolCall.toolId
                        )
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
                .font(.system(size: 11, weight: .medium))
            Text(displayText)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
            if childCount > 0 {
                Text("(\(childCount))")
                    .font(.system(size: 10))
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isExpanded ? Color(.secondarySystemBackground) : Color(.tertiarySystemBackground))
        .cornerRadius(14)
    }

    private var displayText: String {
        guard let input = toolCall.input, !input.isEmpty else {
            return toolCall.name
        }

        switch toolCall.name {
        case "Read", "Write", "Edit":
            let filename = (input as NSString).lastPathComponent
            return "\(toolCall.name) \(filename)"
        case "Bash":
            let truncated = input.prefix(20)
            return truncated.count < input.count ? "\(truncated)..." : String(input)
        case "Glob", "Grep":
            return "\(toolCall.name): \(input)"
        case "Task":
            let parts = input.split(separator: ":", maxSplits: 1)
            return parts.first.map(String.init) ?? input
        default:
            return toolCall.name
        }
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
}
