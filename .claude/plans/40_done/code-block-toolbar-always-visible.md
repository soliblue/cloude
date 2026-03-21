# Code block toolbar always visible (no layout jump during streaming) {rectangle.topthird.inset.filled}
<!-- priority: 10 -->
<!-- tags: ui, markdown, streaming -->
<!-- build: 96 -->

> Removed isSingleLine condition that hid toolbar for single-line code blocks, preventing layout jumps mid-stream.

Removed the `isSingleLine` condition that hid the toolbar for single-line code blocks. Toolbar now always shows, preventing a layout jump mid-stream when a code block gains its second line.

## Desired Outcome
No more vertical shift in content below a code block during streaming.

**Files:** `Cloude/Cloude/UI/StreamingMarkdownView+Blocks.swift`
