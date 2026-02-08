# Rich Tool Output Rendering {text.badge.checkmark}
<!-- priority: 3 -->
<!-- tags: ui, tools -->

> Progressively enhance tool output in ToolDetailSheet by parsing known tag patterns (e.g. `<tool_use_error>`) and rendering them with custom styling, with plain text fallback for anything unrecognized.

## Approach

- Parse `resultOutput` for known XML-like tags before rendering
- Start with `<tool_use_error>` — render with red/error background, hide the tags
- Only apply custom rendering when the **entire output** fits a known pattern cleanly
- If tags are interleaved, mixed, or unrecognized — fall back to plain text (current behavior)
- Additive over time: build up a library of known output patterns as we discover them

## Rules

- **Confidence-first**: if the parser isn't sure, show raw text — never hide content
- **Entire output must parse cleanly** for custom rendering to kick in — no partial transforms
- **Tag library is incremental**: add new tag handlers as we encounter new patterns

## Files
- `Cloude/Cloude/UI/ToolDetailSheet.swift` — output section rendering
- New parser utility (or inline in ToolDetailSheet) for tag detection
