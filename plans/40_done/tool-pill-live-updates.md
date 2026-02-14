# Tool Pill Live Updates
<!-- priority: 10 -->
<!-- tags: tools, ui -->
<!-- build: 56 -->

## Goal
Show live tool execution info without expanding the pill inline. Keep the pill compact, put the detail in the sheet.

## Current State
- Subtitle UI (↳ resultSummary) is commented out in `ChatView+ToolPill.swift`
- The `resultSummary` property exists on `ToolCall` and is populated by the server
- Same pattern was used in `ToolDetailSheet.swift` for child tools

## Original Idea (Rejected)
Show result summaries as subtitles below tool pills. Problem: this expands pills and causes content movement, which conflicts with our UX principle of not shifting content around.

## New Direction
Keep tool pills compact (no inline expansion). Instead, enrich the **tool detail sheet** with:
- **Live output** — show tool output as it streams in (if not too long), similar to how we show input
- **Input** — already shown, keep as-is
- **Status/progress** — show execution state inside the sheet
- The sheet becomes the single place for all tool detail, not the pill itself

## Requirements
- Tool pills stay fixed size — no subtitles, no expansion, no layout shift
- Tool detail sheet gets live-updating content during execution
- Output displayed similarly to how input/history is shown (same visual treatment)
- Truncation for long outputs (show first N lines with expand option?)
- No message movement in the chat stream

## Files
- `Cloude/Cloude/UI/ChatView+ToolPill.swift` — main pill view (subtitle stays commented out / removed)
- `Cloude/Cloude/UI/ToolDetailSheet.swift` — primary target for live updates
- `Cloude/CloudeShared/Sources/CloudeShared/Messages/ServerMessage.swift` — ToolCall model
