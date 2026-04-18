# Markdown Rendered Preview {doc.richtext}
<!-- priority: 10 -->
<!-- tags: file-preview, markdown -->
<!-- build: 56 -->

> Added rendered markdown preview for .md files with toggle to source view.

File viewer now defaults to rendered markdown for `.md` files instead of showing raw source. Uses the existing `StreamingMarkdownView` (same renderer as chat messages) for full markdown support — headers, code blocks, tables, lists, blockquotes, inline formatting. Toggle button in toolbar switches between rendered view (doc.richtext icon) and syntax-highlighted source (`</>` icon).
