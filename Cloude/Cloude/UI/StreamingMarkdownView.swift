import SwiftUI

struct StreamingMarkdownView: View {
    let text: String
    var toolCalls: [ToolCall] = []
    var isComplete: Bool = true
    @State private var frozenBlocks: [StreamingBlock] = []
    @State private var frozenUpTo: String = ""
    @State private var tailBlocks: [StreamingBlock] = []
    @State private var lastText: String = ""
    @State private var lastToolCount: Int = 0
    @State private var collapsedHeaders: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(contentTree.enumerated()), id: \.offset) { _, node in
                ContentNodeView(
                    node: node,
                    collapsedHeaders: collapsedHeaders,
                    isComplete: isComplete,
                    onToggle: { toggleCollapse($0) }
                )
                .padding(.bottom, 8)
            }
        }
        .onAppear { updateIncremental() }
        .onChange(of: text) { _, _ in updateIncremental() }
        .onChange(of: toolCalls.count) { _, _ in updateIncremental() }
    }

    private var allBlocks: [StreamingBlock] {
        frozenBlocks + tailBlocks
    }

    private func updateIncremental() {
        if text == lastText && toolCalls.count == lastToolCount { return }
        lastText = text
        lastToolCount = toolCalls.count

        if !toolCalls.isEmpty {
            frozenBlocks = []
            frozenUpTo = ""
            tailBlocks = StreamingMarkdownParser.parseWithToolCalls(text, toolCalls: toolCalls)
            return
        }

        let splitIndex = stableSplitPoint(in: text)

        if let splitIndex {
            let frozenStr = String(text[text.startIndex..<splitIndex])
            if frozenStr != frozenUpTo {
                frozenBlocks = StreamingMarkdownParser.parse(frozenStr)
                frozenUpTo = frozenStr
            }
            let tail = String(text[splitIndex...])
            tailBlocks = StreamingMarkdownParser.parse(tail)
        } else {
            frozenBlocks = []
            frozenUpTo = ""
            tailBlocks = StreamingMarkdownParser.parse(text)
        }
    }

    private func stableSplitPoint(in text: String) -> String.Index? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var insideFence = false
        var lastBlankOutsideFence: Int? = nil

        var prevWasBlank = false
        var prevBlankIndex: Int? = nil

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                insideFence = !insideFence
            }
            if !insideFence && trimmed.isEmpty && i > 0 {
                prevWasBlank = true
                prevBlankIndex = i
            } else if !insideFence && !trimmed.isEmpty && prevWasBlank {
                if let blankIdx = prevBlankIndex {
                    lastBlankOutsideFence = blankIdx
                }
                prevWasBlank = false
            } else {
                prevWasBlank = false
            }
        }

        if let blankLine = lastBlankOutsideFence {
            var offset = 0
            for i in 0...blankLine {
                offset += lines[i].count + 1
            }
            if offset <= text.count {
                return text.index(text.startIndex, offsetBy: offset)
            }
        }
        return nil
    }

    private func toggleCollapse(_ headerId: String) {
        if collapsedHeaders.contains(headerId) {
            collapsedHeaders.remove(headerId)
        } else {
            collapsedHeaders.insert(headerId)
        }
    }

    private var contentTree: [ContentNode] {
        buildTree(from: allBlocks)
    }

    private func buildTree(from blocks: [StreamingBlock]) -> [ContentNode] {
        var result: [ContentNode] = []
        var index = 0

        func parseChildren(parentLevel: Int) -> [ContentNode] {
            var children: [ContentNode] = []
            while index < blocks.count {
                let block = blocks[index]
                if case .header(_, let level, _, _) = block {
                    if level <= parentLevel {
                        break
                    }
                    index += 1
                    let subchildren = parseChildren(parentLevel: level)
                    children.append(.header(block: block, children: subchildren))
                } else {
                    children.append(.content(block: block))
                    index += 1
                }
            }
            return children
        }

        while index < blocks.count {
            let block = blocks[index]
            if case .header(_, let level, _, _) = block {
                index += 1
                let children = parseChildren(parentLevel: level)
                result.append(.header(block: block, children: children))
            } else {
                result.append(.content(block: block))
                index += 1
            }
        }

        return result
    }
}

private indirect enum ContentNode {
    case content(block: StreamingBlock)
    case header(block: StreamingBlock, children: [ContentNode])

    var id: String {
        switch self {
        case .content(let block): return block.id
        case .header(let block, _): return block.id
        }
    }
}

private struct ContentNodeView: View {
    let node: ContentNode
    let collapsedHeaders: Set<String>
    let isComplete: Bool
    let onToggle: (String) -> Void

    var body: some View {
        switch node {
        case .content(let block):
            StreamingBlockView(block: block)
        case .header(let block, let children):
            HeaderSectionView(
                block: block,
                children: children,
                isCollapsed: collapsedHeaders.contains(block.id),
                collapsedHeaders: collapsedHeaders,
                isComplete: isComplete,
                onToggle: onToggle
            )
        }
    }
}

private struct HeaderSectionView: View {
    let block: StreamingBlock
    let children: [ContentNode]
    let isCollapsed: Bool
    let collapsedHeaders: Set<String>
    let isComplete: Bool
    let onToggle: (String) -> Void

    private var headerContent: AttributedString {
        if case .header(_, _, let content, _) = block { return content }
        return AttributedString()
    }

    private var headerSegments: [InlineSegment] {
        if case .header(_, _, _, let segments) = block { return segments }
        return []
    }

    private var hasSpecialSegments: Bool {
        headerSegments.contains(where: \.isSpecial)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                if isComplete && !children.isEmpty {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                }

                if hasSpecialSegments {
                    InlineTextView(segments: headerSegments)
                } else {
                    Text(headerContent)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isComplete && !children.isEmpty {
                    onToggle(block.id)
                }
            }

            if !isCollapsed {
                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    ContentNodeView(
                        node: child,
                        collapsedHeaders: collapsedHeaders,
                        isComplete: isComplete,
                        onToggle: onToggle
                    )
                }
            }
        }
    }
}

struct StreamingBlockView: View {
    let block: StreamingBlock

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
        VStack(alignment: .leading, spacing: 8) {
            ForEach(widgets, id: \.parent.toolId) { item in
                WidgetRegistry.view(for: item.parent.name, input: item.parent.input)
            }

            if !nonWidgets.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(nonWidgets, id: \.parent.toolId) { item in
                            InlineToolPill(toolCall: item.parent, children: item.children)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, -16)
                .scrollClipDisabled()
            }
        }
    }
}
