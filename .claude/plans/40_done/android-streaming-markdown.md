# Android Streaming Markdown Renderer {text.quote}
<!-- priority: 5 -->
<!-- tags: android, ui, markdown -->

> Port the streaming markdown parser and renderer to Compose (code blocks, syntax highlighting, tables, inline formatting).

## Desired Outcome
Full markdown rendering matching iOS quality: headers, bold/italic/strikethrough, code blocks with syntax highlighting, tables, blockquotes, lists, links, inline code. Must handle streaming (text arriving chunk by chunk).

**Files (iOS reference):** StreamingMarkdownParser.swift (+6 extension files), StreamingMarkdownView.swift (+6 extension files)
