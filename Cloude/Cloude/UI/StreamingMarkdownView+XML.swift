import SwiftUI

struct XMLBlockView: View {
    let nodes: [XMLNode]
    @State private var showSource = false

    private var rawXML: String {
        nodes.map { $0.toXMLString(depth: 0) }.joined(separator: "\n")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.s) {
                Text("xml")
                    .font(.system(size: DS.Text.s, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Button { showSource.toggle() } label: {
                    Image(systemName: showSource ? "text.word.spacing" : "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: DS.Text.s))
                        .foregroundStyle(.secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .padding(.horizontal, DS.Spacing.m)
            .padding(.vertical, DS.Spacing.s)

            Divider().overlay(Color.gray.opacity(DS.Opacity.m))

            if showSource {
                Text(rawXML)
                    .font(.system(size: DS.Text.s, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DS.Spacing.m)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(nodes) { node in
                        XMLNodeView(node: node, depth: 0)
                    }
                }
                .padding(DS.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.themeSecondary)
        .cornerRadius(DS.Radius.s)
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
            HStack(alignment: .top, spacing: DS.Spacing.xs) {
                if hasChildren {
                    Button { expanded.toggle() } label: {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: DS.Text.s, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: DS.Spacing.m, height: DS.Spacing.l)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: DS.Spacing.m)
                }

                Text(node.tagName)
                    .font(.system(size: DS.Text.s, weight: .medium, design: .monospaced))
                    .foregroundColor(.purple)

                if !node.attributes.isEmpty {
                    ForEach(Array(node.attributes.enumerated()), id: \.offset) { _, attr in
                        Text(attr.key)
                            .font(.system(size: DS.Text.s, design: .monospaced))
                            .foregroundColor(.orange)
                        if !attr.value.isEmpty {
                            Text("=")
                                .font(.system(size: DS.Text.s, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text(attr.value)
                                .font(.system(size: DS.Text.s, design: .monospaced))
                                .foregroundColor(.green)
                        }
                    }
                }

                if node.isSelfClosing {
                    Text("/")
                        .font(.system(size: DS.Text.s, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                if let text = node.textContent, node.children.isEmpty {
                    Text(text)
                        .font(.system(size: DS.Text.s, design: .monospaced))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, DS.Spacing.xs)

            if expanded && hasChildren {
                VStack(alignment: .leading, spacing: 0) {
                    if let text = node.textContent {
                        HStack(alignment: .top, spacing: DS.Spacing.xs) {
                            Spacer().frame(width: DS.Spacing.m)
                            Text(text)
                                .font(.system(size: DS.Text.s, design: .monospaced))
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, DS.Spacing.xs)
                    }

                    ForEach(node.children) { child in
                        XMLNodeView(node: child, depth: depth + 1)
                    }
                }
                .padding(.leading, DS.Spacing.l)
            }
        }
    }
}
