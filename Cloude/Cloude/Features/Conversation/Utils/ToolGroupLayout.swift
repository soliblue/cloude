import Foundation
import CloudeShared

private enum WidgetTool {
    static func isWidget(_ toolName: String) -> Bool {
        toolName.hasPrefix("mcp__widgets__")
    }
}

struct ToolGroupNode: Equatable {
    let parent: ToolCall
    let children: [ToolCall]
}

enum ToolGroupRenderItem: Identifiable, Equatable {
    case widget(parent: ToolCall, children: [ToolCall])
    case pills(id: String, items: [ToolGroupNode])

    var id: String {
        switch self {
        case .widget(let parent, _):
            return "widget-\(parent.toolId)"
        case .pills(let id, _):
            return "pills-\(id)"
        }
    }
}

enum ToolGroupLayout {
    static func hierarchy(for tools: [ToolCall]) -> [ToolGroupNode] {
        var childrenByParent: [String: [ToolCall]] = [:]
        var topLevel: [ToolCall] = []

        for tool in tools {
            if let parentToolId = tool.parentToolId {
                childrenByParent[parentToolId, default: []].append(tool)
            } else {
                topLevel.append(tool)
            }
        }

        return topLevel.map { ToolGroupNode(parent: $0, children: childrenByParent[$0.toolId] ?? []) }
    }

    static func orderedItems(for tools: [ToolCall]) -> [ToolGroupRenderItem] {
        var result: [ToolGroupRenderItem] = []
        var pendingPills: [ToolGroupNode] = []

        for node in hierarchy(for: tools) {
            if WidgetTool.isWidget(node.parent.name) {
                if !pendingPills.isEmpty {
                    result.append(.pills(id: pendingPills.map(\.parent.toolId).joined(separator: "-"), items: pendingPills))
                    pendingPills = []
                }
                result.append(.widget(parent: node.parent, children: node.children))
            } else {
                pendingPills.append(node)
            }
        }

        if !pendingPills.isEmpty {
            result.append(.pills(id: pendingPills.map(\.parent.toolId).joined(separator: "-"), items: pendingPills))
        }

        return result
    }
}
