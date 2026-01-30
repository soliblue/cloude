//
//  StreamingMarkdownView.swift
//  Cloude

import SwiftUI

struct StreamingMarkdownView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(StreamingMarkdownParser.parse(text)) { block in
                StreamingBlockView(block: block)
            }
        }
    }
}

struct StreamingBlockView: View {
    let block: StreamingBlock

    var body: some View {
        switch block {
        case .text(_, let attributed):
            Text(attributed)
                .textSelection(.enabled)

        case .code(_, let content, let language, _):
            CodeBlock(code: content, language: language)

        case .table(_, let rows):
            MarkdownTableView(rows: rows)

        case .blockquote(_, let content):
            BlockquoteView(text: content)

        case .horizontalRule(_):
            HorizontalRuleView()
        }
    }
}
