import SwiftUI

struct StreamingBlockView: View {
    let block: StreamingBlock
    var onSelectTool: ((ToolCall, [ToolCall]) -> Void)?

    var body: some View {
        switch block {
        case .text(_, let attributed, let segments):
            if segments.contains(where: \.isSpecial) {
                InlineTextView(segments: segments)
            } else {
                Text(attributed)
                    .contentTransition(.interpolate)
            }

        case .code(_, let content, let language, _):
            CodeBlock(code: content, language: language)

        case .table(_, let rows):
            MarkdownTableView(rows: rows)

        case .blockquote(_, let content):
            BlockquoteView(text: content)

        case .horizontalRule(_):
            HorizontalRuleView()

        case .header(_, _, let content, let segments):
            if segments.contains(where: \.isSpecial) {
                InlineTextView(segments: segments)
            } else {
                Text(content)
                    .contentTransition(.interpolate)
            }

        case .toolGroup(_, let tools):
            ToolGroupView(tools: tools, onSelectTool: onSelectTool)

        case .xml(_, let nodes):
            XMLBlockView(nodes: nodes)
        }
    }
}

struct ToolGroupView: View {
    let tools: [ToolCall]
    var onSelectTool: ((ToolCall, [ToolCall]) -> Void)?

    private var toolHierarchy: [(parent: ToolCall, children: [ToolCall])] {
        var childrenByParent: [String: [ToolCall]] = [:]
        var topLevel: [ToolCall] = []
        for tool in tools {
            if let parentId = tool.parentToolId {
                childrenByParent[parentId, default: []].append(tool)
            } else {
                topLevel.append(tool)
            }
        }
        return topLevel.map { ($0, childrenByParent[$0.toolId] ?? []) }
    }

    var body: some View {
        let hierarchy = toolHierarchy
        if !hierarchy.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.s) {
                    ForEach(hierarchy, id: \.parent.toolId) { item in
                        InlineToolPill(toolCall: item.parent, children: item.children) {
                            onSelectTool?(item.parent, item.children)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.l)
            }
            .padding(.horizontal, -DS.Spacing.l)
            .scrollClipDisabled()
        }
    }
}

struct ToolDetailItem: Identifiable {
    let toolCall: ToolCall
    let children: [ToolCall]
    var id: String { toolCall.toolId }
}
