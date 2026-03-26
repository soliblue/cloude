// StreamingMarkdownView+ToolGroup.swift

import SwiftUI

struct StreamingBlockView: View {
    let block: StreamingBlock

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
            ToolGroupView(tools: tools)

        case .xml(_, let nodes):
            XMLBlockView(nodes: nodes)
        }
    }
}

struct ToolGroupView: View {
    let tools: [ToolCall]

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

    private var widgets: [(parent: ToolCall, children: [ToolCall])] {
        toolHierarchy.filter { WidgetRegistry.isWidget($0.parent.name) }
    }

    private var nonWidgets: [(parent: ToolCall, children: [ToolCall])] {
        toolHierarchy.filter { !WidgetRegistry.isWidget($0.parent.name) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            ForEach(widgets, id: \.parent.toolId) { item in
                WidgetRegistry.view(for: item.parent.name, input: item.parent.input)
            }

            if !nonWidgets.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.s) {
                        ForEach(nonWidgets, id: \.parent.toolId) { item in
                            InlineToolPill(toolCall: item.parent, children: item.children)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.l)
                }
                .padding(.horizontal, -16)
                .scrollClipDisabled()
            }
        }
    }
}
