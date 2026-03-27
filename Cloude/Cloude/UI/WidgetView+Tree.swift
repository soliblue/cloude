import SwiftUI

struct TreeWidget: View {
    let data: [String: Any]
    @State private var collapsed: Set<String> = []

    private var title: String? { data["title"] as? String }
    private var root: TreeNode? { parseNode(data["root"] as? [String: Any]) }

    var body: some View {
        WidgetContainer {
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
                        .fill(Color.secondary.opacity(DS.Opacity.medium))
                        .frame(width: DS.Size.hairline)
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, DS.Spacing.s)
                } else {
                    Color.clear.frame(width: DS.Spacing.l)
                }
            }

            if depth > 0 {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.secondary.opacity(DS.Opacity.medium))
                        .frame(width: DS.Size.xs, height: 1)
                        .padding(.top, DS.Spacing.s)
                    Spacer(minLength: 3)
                }
                .frame(width: DS.Spacing.m)
            }

            Image(systemName: node.icon)
                .font(.system(size: DS.Text.s))
                .foregroundColor(node.iconColor)
                .frame(width: DS.Size.s)
                .padding(.top, DS.Spacing.xs)

            Spacer().frame(width: DS.Spacing.xs)

            if hasChildren {
                Button {
                    withAnimation(.easeInOut(duration: DS.Duration.quick)) {
                        if isCollapsed { collapsed.remove(node.id) } else { collapsed.insert(node.id) }
                    }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(node.label)
                            .font(.system(size: DS.Text.m, weight: .medium))
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: DS.Text.m, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text(node.label)
                    .font(.system(size: DS.Text.m))
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
        if let name { return .fromName(name, default: hasChildren ? .yellow : .blue) }
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
