import SwiftUI

struct StreamingMarkdownView: View {
    let text: String
    var toolCalls: [ToolCall] = []
    var isComplete: Bool = true
    @State private var cachedBlocks: [StreamingBlock] = []
    @State private var cachedText: String = ""
    @State private var cachedToolCount: Int = 0
    @State private var collapsedHeaders: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(contentTree.enumerated()), id: \.offset) { _, node in
                ContentNodeView(
                    node: node,
                    collapsedHeaders: collapsedHeaders,
                    isComplete: isComplete,
                    onToggle: { toggleCollapse($0) }
                )
            }
        }
        .onAppear { updateCacheIfNeeded() }
        .onChange(of: text) { _, _ in updateCacheIfNeeded() }
        .onChange(of: toolCalls.count) { _, _ in updateCacheIfNeeded() }
    }

    private var blocks: [StreamingBlock] {
        if cachedText == text && cachedToolCount == toolCalls.count {
            return cachedBlocks
        }
        if toolCalls.isEmpty {
            return StreamingMarkdownParser.parse(text)
        }
        return StreamingMarkdownParser.parseWithToolCalls(text, toolCalls: toolCalls)
    }

    private func updateCacheIfNeeded() {
        if cachedText != text || cachedToolCount != toolCalls.count {
            if toolCalls.isEmpty {
                cachedBlocks = StreamingMarkdownParser.parse(text)
            } else {
                cachedBlocks = StreamingMarkdownParser.parseWithToolCalls(text, toolCalls: toolCalls)
            }
            cachedText = text
            cachedToolCount = toolCalls.count
        }
    }

    private func toggleCollapse(_ headerId: String) {
        if collapsedHeaders.contains(headerId) {
            collapsedHeaders.remove(headerId)
        } else {
            collapsedHeaders.insert(headerId)
        }
    }

    private var contentTree: [ContentNode] {
        buildTree(from: blocks)
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
        headerSegments.contains { segment in
            switch segment {
            case .code, .filePath: return true
            default: return false
            }
        }
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
                        .textSelection(.enabled)
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
            let hasSpecialSegments = segments.contains { segment in
                switch segment {
                case .code, .filePath: return true
                default: return false
                }
            }
            if hasSpecialSegments {
                InlineTextView(segments: segments)
            } else {
                Text(attributed)
                    .textSelection(.enabled)
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
            let hasSpecialSegments = segments.contains { segment in
                switch segment {
                case .code, .filePath: return true
                default: return false
                }
            }
            if hasSpecialSegments {
                InlineTextView(segments: segments)
            } else {
                Text(content)
                    .textSelection(.enabled)
            }

        case .toolGroup(_, let tools):
            ToolGroupView(tools: tools)
        }
    }
}

struct ToolGroupView: View {
    let tools: [ToolCall]

    private var toolHierarchy: [(parent: ToolCall, children: [ToolCall])] {
        let topLevel = tools.filter { $0.parentToolId == nil }.reversed()
        return topLevel.map { parent in
            let children = tools.filter { $0.parentToolId == parent.toolId }
            return (parent, children)
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(toolHierarchy, id: \.parent.toolId) { item in
                    InlineToolPill(toolCall: item.parent, children: item.children)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
    }
}
