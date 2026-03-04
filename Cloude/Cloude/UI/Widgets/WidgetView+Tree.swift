import SwiftUI

struct TreeWidget: View {
    let data: [String: Any]
    @State private var collapsed: Set<String> = []

    private var title: String? { data["title"] as? String }
    private var root: TreeNode? { parseNode(data["root"] as? [String: Any]) }

    var body: some View {
        WidgetContainer {
            WidgetHeader(icon: "filemenu.and.selection", title: title ?? "Tree", color: .yellow) {
                WidgetButton(icon: "arrow.up.left.and.arrow.down.right", color: .yellow, enabled: !collapsed.isEmpty) {
                    collapsed = []
                }
                WidgetButton(icon: "arrow.down.right.and.arrow.up.left", color: .yellow, enabled: true) {
                    collapseAll(root)
                }
            }

            if let root {
                nodeView(root, depth: 0, isLast: true, prefixSegments: [])
            }
        }
    }

    @ViewBuilder
    private func nodeView(_ node: TreeNode, depth: Int, isLast: Bool, prefixSegments: [Bool]) -> some View {
        let isCollapsed = collapsed.contains(node.id)
        let hasChildren = !node.children.isEmpty

        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(prefixSegments.enumerated()), id: \.offset) { _, showLine in
                if showLine {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, 9)
                } else {
                    Color.clear.frame(width: 20)
                }
            }

            if depth > 0 {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 12, height: 1)
                        .padding(.top, 10)
                    Spacer(minLength: 4)
                }
                .frame(width: 16)
            }

            Image(systemName: node.icon)
                .font(.system(size: 12))
                .foregroundColor(node.iconColor)
                .frame(width: 18)
                .padding(.top, 2)

            if hasChildren {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if isCollapsed { collapsed.remove(node.id) } else { collapsed.insert(node.id) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(node.label)
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text(node.label)
                    .font(.system(size: 13))
            }

            Spacer()
        }

        if hasChildren && !isCollapsed {
            let childSegments = prefixSegments + [!isLast && depth > 0]
            ForEach(Array(node.children.enumerated()), id: \.element.id) { idx, child in
                AnyView(nodeView(child, depth: depth + 1, isLast: idx == node.children.count - 1, prefixSegments: depth == 0 ? [] : childSegments))
            }
        }
    }

    private func collapseAll(_ node: TreeNode?) {
        guard let node else { return }
        if !node.children.isEmpty { collapsed.insert(node.id) }
        node.children.forEach { collapseAll($0) }
    }

    private func parseNode(_ dict: [String: Any]?, path: String = "") -> TreeNode? {
        guard let dict, let label = dict["label"] as? String else { return nil }
        let nodePath = path.isEmpty ? label : "\(path)/\(label)"
        let icon = dict["icon"] as? String ?? (dict["children"] != nil ? "folder.fill" : "doc.fill")
        let color = parseColor(dict["color"] as? String, hasChildren: dict["children"] != nil)
        let children = (dict["children"] as? [[String: Any]])?.compactMap { parseNode($0, path: nodePath) } ?? []
        return TreeNode(id: nodePath, label: label, icon: icon, iconColor: color, children: children)
    }

    private func parseColor(_ name: String?, hasChildren: Bool) -> Color {
        if let name {
            switch name {
            case "red": return .red
            case "orange": return .orange
            case "yellow": return .yellow
            case "green": return .green
            case "blue": return .blue
            case "teal": return .teal
            case "purple": return .purple
            case "pink": return .pink
            default: break
            }
        }
        return hasChildren ? .yellow : .blue
    }
}

private class TreeNode: Identifiable {
    let id: String
    let label: String
    let icon: String
    let iconColor: Color
    let children: [TreeNode]

    init(id: String, label: String, icon: String, iconColor: Color, children: [TreeNode]) {
        self.id = id
        self.label = label
        self.icon = icon
        self.iconColor = iconColor
        self.children = children
    }
}
