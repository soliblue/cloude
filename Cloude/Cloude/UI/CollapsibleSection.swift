//
//  CollapsibleSection.swift
//  Cloude
//

import SwiftUI

struct CollapsibleSection: View {
    let title: String
    let level: Int
    let content: [ContentBlock]

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 12)

                    Text(title)
                        .font(fontForLevel)
                        .foregroundColor(.primary)

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(content.enumerated()), id: \.offset) { _, block in
                        ContentBlockView(block: block)
                    }
                }
                .padding(.leading, 18)
            }
        }
    }

    private var fontForLevel: Font {
        switch level {
        case 1: return .title2.bold()
        case 2: return .title3.bold()
        default: return .headline
        }
    }
}

struct ContentBlockView: View {
    let block: ContentBlock

    var body: some View {
        switch block {
        case .text(let content):
            MarkdownText(text: content)
        case .code(let content, let language):
            CodeBlock(code: content, language: language)
        case .table(let rows):
            MarkdownTableView(rows: rows)
        case .blockquote(let content):
            BlockquoteView(text: content)
        case .section(let title, let level, let children):
            CollapsibleSection(title: title, level: level, content: children)
        case .horizontalRule:
            HorizontalRuleView()
        }
    }
}

struct HorizontalRuleView: View {
    var body: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 1)
            .padding(.vertical, 8)
    }
}
