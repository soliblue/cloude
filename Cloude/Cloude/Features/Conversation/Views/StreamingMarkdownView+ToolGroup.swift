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
            }

        case .toolGroup(_, let tools):
            ToolGroupView(blockId: block.id, tools: tools, onSelectTool: onSelectTool)
                .equatable()

        case .xml(_, let nodes):
            XMLBlockView(nodes: nodes)
        }
    }
}

struct ToolGroupView: View, Equatable {
    let blockId: String
    let tools: [ToolCall]
    var onSelectTool: ((ToolCall, [ToolCall]) -> Void)?

    static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.blockId == rhs.blockId, lhs.tools.count == rhs.tools.count else { return false }
        for i in lhs.tools.indices {
            if lhs.tools[i].toolId != rhs.tools[i].toolId || lhs.tools[i].state != rhs.tools[i].state { return false }
        }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            ForEach(ToolGroupLayout.orderedItems(for: tools)) { group in
                switch group {
                case .widget(let parent, _):
                    WidgetRegistry.view(for: parent.name, input: parent.input)
                case .pills(_, let items):
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Spacing.s) {
                            ForEach(items, id: \.parent.toolId) { node in
                                InlineToolPill(toolCall: node.parent, children: node.children) {
                                    onSelectTool?(node.parent, node.children)
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
    }
}

struct ToolDetailItem: Identifiable {
    let toolCall: ToolCall
    let children: [ToolCall]
    var id: String { toolCall.toolId }
}
