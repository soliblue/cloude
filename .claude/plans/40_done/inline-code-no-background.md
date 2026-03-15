# Inline Code: Remove Background Color

Removed `backgroundColor` from inline code rendering. Inline code still renders monospaced, just without the `.secondary.opacity(0.1)` background.

**Files:** `StreamingMarkdownView+InlineText.swift`

## Test
- Send a message with inline code (backticks) and verify no background color appears
- Inline code should still be monospaced font
