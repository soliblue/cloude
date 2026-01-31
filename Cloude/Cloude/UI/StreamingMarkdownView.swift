//
//  StreamingMarkdownView.swift
//  Cloude

import SwiftUI

struct StreamingMarkdownView: View {
    let text: String
    @State private var cachedBlocks: [StreamingBlock] = []
    @State private var cachedText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(blocks) { block in
                StreamingBlockView(block: block)
            }
        }
        .onAppear { updateCacheIfNeeded() }
        .onChange(of: text) { _, _ in updateCacheIfNeeded() }
    }

    private var blocks: [StreamingBlock] {
        cachedText == text ? cachedBlocks : StreamingMarkdownParser.parse(text)
    }

    private func updateCacheIfNeeded() {
        if cachedText != text {
            cachedBlocks = StreamingMarkdownParser.parse(text)
            cachedText = text
        }
    }
}

struct StreamingBlockView: View {
    let block: StreamingBlock

    var body: some View {
        switch block {
        case .text(_, let attributed, let segments):
            if segments.contains(where: { if case .code = $0 { return true } else { return false } }) {
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
        }
    }
}
