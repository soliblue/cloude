# Agent Tool Output as Markdown {text.document}
<!-- priority: 10 -->
<!-- tags: agent, tool-pill, markdown -->

> Agent tool results in ToolDetailSheet now render via StreamingMarkdownView instead of monospaced Text.

Agent tool results in ToolDetailSheet now render via `StreamingMarkdownView` instead of monospaced `Text`.

## Changes
- **`ToolDetailSheet.swift:106-107`** - Route Agent output to `markdownOutputSection`
- **`ToolDetailSheet+Content.swift:62-74`** - New `markdownOutputSection` using `StreamingMarkdownView`

**Files:** `ToolDetailSheet.swift`, `ToolDetailSheet+Content.swift`
