//
//  MarkdownText.swift
//  Cloude
//

import SwiftUI

struct MarkdownText: View {
    let text: String

    var body: some View {
        Text(StreamingMarkdownParser.parseInlineMarkdown(text))
            .textSelection(.enabled)
    }
}

struct RichTextView: View {
    let text: String

    var body: some View {
        StreamingMarkdownView(text: text)
    }
}
