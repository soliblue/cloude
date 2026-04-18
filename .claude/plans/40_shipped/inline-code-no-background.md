# Inline Code: Remove Background Color {chevron.left.forwardslash.chevron.right}
<!-- priority: 10 -->
<!-- tags: ui, markdown -->

> Removed background color from inline code rendering, keeping only monospaced font.

**Files:** `StreamingMarkdownView+InlineText.swift`

## Test
- Send a message with inline code (backticks) and verify no background color appears
- Inline code should still be monospaced font
