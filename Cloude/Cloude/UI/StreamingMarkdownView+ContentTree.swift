// StreamingMarkdownView+ContentTree.swift

import SwiftUI

indirect enum ContentNode {
    case content(block: StreamingBlock)
    case header(block: StreamingBlock, children: [ContentNode])

    var id: String {
        switch self {
        case .content(let block): return block.id
        case .header(let block, _): return block.id
        }
    }
}

struct ContentNodeView: View {
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

struct HeaderSectionView: View {
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

func buildContentTree(from blocks: [StreamingBlock]) -> [ContentNode] {
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
