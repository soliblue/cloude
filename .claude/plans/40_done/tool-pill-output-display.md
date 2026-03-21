# Tool Pill Sheet - Rich Output Display {doc.richtext}
<!-- priority: 10 -->
<!-- tags: tool-pill, ui -->
<!-- build: 86 -->

> Added syntax-highlighted code block rendering for Read tool output in the tool detail sheet.

## Phase 1: Rich Read output (current)

Strip line number prefixes from Read resultOutput, detect language from file extension, render as `CodeBlock` instead of plain monospace text. No agent-side changes needed.

**Files to modify:**
- `ToolDetailSheet.swift` - route Read to new view
- `ToolDetailSheet+Content.swift` - add readOutputSection using CodeBlock

**Steps:**
1. Add helper to strip `     N→` prefix from Read output lines
2. Add helper to detect language from file path extension
3. Add `readOutputSection` that renders a `CodeBlock` with syntax highlighting
4. Route Read tool calls to new view in body, fallback to generic outputSection

## Phase 2: Rich Write/Edit output (later)

Requires sending `extraInput` from Mac agent (content for Write, old_string/new_string for Edit). Deferred.
