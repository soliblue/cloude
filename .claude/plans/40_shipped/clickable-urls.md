# Clickable URL Pills {link}
<!-- priority: 10 -->
<!-- tags: ui, markdown -->
<!-- build: 77 -->

> HTTPS/HTTP URLs in chat messages now render as tappable blue pills that open in Safari.

HTTPS/HTTP URLs in chat messages now render as tappable blue pills (like file path pills) that open in Safari.

## Changes
- `StreamingMarkdownParser+Inline.swift`: Added `parseURL()` — extracts bare URLs, shows domain + truncated path
- `StreamingMarkdownView+InlineText.swift`: Added `.url` case to `InlineSegment` with blue pill rendering
- `StreamingMarkdownView.swift`: Added `.url` to `hasSpecialSegments` checks (3 places)

## Test
- Bare URL in message: `https://github.com/anthropics/claude-code` → tappable blue pill showing `github.com/anthropics/claud…`
- URL at end of sentence with period: `Check https://example.com.` → pill doesn't include trailing period
- Markdown link `[text](url)` still works as before (rendered as linked text, not pill)
- URLs inside code blocks should NOT become pills (code blocks are parsed first)
