import SwiftUI

struct FilePreviewXMLRow: View {
    let node: FilePreviewXMLNode
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
            if node.children.isEmpty {
                leaf
            } else {
                Button {
                    isExpanded.toggle()
                } label: {
                    openTag
                }
                .buttonStyle(.plain)
                if isExpanded {
                    ForEach(node.children.indices, id: \.self) { i in
                        FilePreviewXMLRow(node: node.children[i])
                            .padding(.leading, ThemeTokens.Spacing.m)
                    }
                    closeTag
                }
            }
        }
        .appFont(size: ThemeTokens.Text.m, design: .monospaced)
    }

    private var leaf: some View {
        HStack(spacing: 0) {
            blue("<")
            blue(node.name)
            attributes
            if node.text.isEmpty {
                blue(" />")
            } else {
                blue(">")
                Text(node.text).foregroundColor(.primary)
                blue("</")
                blue(node.name)
                blue(">")
            }
        }
        .textSelection(.enabled)
    }

    private var openTag: some View {
        HStack(spacing: ThemeTokens.Spacing.xs) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .foregroundColor(.secondary)
            HStack(spacing: 0) {
                blue("<")
                blue(node.name)
                attributes
                blue(">")
            }
        }
    }

    private var closeTag: some View {
        HStack(spacing: 0) {
            blue("</")
            blue(node.name)
            blue(">")
        }
    }

    @ViewBuilder
    private var attributes: some View {
        ForEach(Array(node.attributes.keys).sorted(), id: \.self) { key in
            HStack(spacing: 0) {
                Text(" \(key)=").foregroundColor(ThemeColor.orange)
                Text("\"\(node.attributes[key] ?? "")\"").foregroundColor(ThemeColor.green)
            }
        }
    }

    private func blue(_ string: String) -> Text {
        Text(string).foregroundColor(ThemeColor.blue)
    }
}
