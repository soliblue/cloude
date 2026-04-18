---
title: "Markdown Rendered Preview"
description: "Added rendered markdown preview for .md files with toggle to source view."
created_at: 2026-02-07
tags: ["file-preview", "markdown"]
icon: doc.richtext
build: 43
---


# Markdown Rendered Preview {doc.richtext}
File viewer now defaults to rendered markdown for `.md` files instead of showing raw source. Uses the existing `StreamingMarkdownView` (same renderer as chat messages) for full markdown support — headers, code blocks, tables, lists, blockquotes, inline formatting. Toggle button in toolbar switches between rendered view (doc.richtext icon) and syntax-highlighted source (`</>` icon).
