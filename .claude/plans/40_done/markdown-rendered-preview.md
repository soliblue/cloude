# Markdown Rendered Preview
<!-- priority: 10 -->
<!-- tags: files, markdown -->
<!-- build: 56 -->

File viewer now defaults to rendered markdown for `.md` files instead of showing raw source. Uses the existing `StreamingMarkdownView` (same renderer as chat messages) for full markdown support — headers, code blocks, tables, lists, blockquotes, inline formatting. Toggle button in toolbar switches between rendered view (doc.richtext icon) and syntax-highlighted source (`</>` icon).
