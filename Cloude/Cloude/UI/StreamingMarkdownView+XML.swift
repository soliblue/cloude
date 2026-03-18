import SwiftUI

struct XMLBlockView: View {
    let nodes: [XMLNode]
    @State private var showSource = false

    private var rawXML: String {
        nodes.map { $0.toXMLString(depth: 0) }.joined(separator: "\n")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("xml")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Button { showSource.toggle() } label: {
                    Image(systemName: showSource ? "text.word.spacing" : "chevron.left.forwardslash.chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().overlay(Color.gray.opacity(0.3))

            if showSource {
                Text(rawXML)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(nodes) { node in
                        XMLNodeView(node: node, depth: 0)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.themeSecondary)
        .cornerRadius(6)
    }
}

private struct XMLNodeView: View {
    let node: XMLNode
    let depth: Int
    @State private var expanded = true

    private var hasChildren: Bool {
        !node.children.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                if hasChildren {
                    Button { expanded.toggle() } label: {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 12, height: 16)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 12)
                }

                Text(node.tagName)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.purple)

                if !node.attributes.isEmpty {
                    ForEach(Array(node.attributes.enumerated()), id: \.offset) { _, attr in
                        Text(attr.key)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.orange)
                        if !attr.value.isEmpty {
                            Text("=")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text(attr.value)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.green)
                        }
                    }
                }

                if node.isSelfClosing {
                    Text("/")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                if let text = node.textContent, node.children.isEmpty {
                    Text(text)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 3)

            if expanded && hasChildren {
                VStack(alignment: .leading, spacing: 0) {
                    if let text = node.textContent {
                        HStack(alignment: .top, spacing: 4) {
                            Spacer().frame(width: 12)
                            Text(text)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 3)
                    }

                    ForEach(node.children) { child in
                        XMLNodeView(node: child, depth: depth + 1)
                    }
                }
                .padding(.leading, 16)
            }
        }
    }
}
