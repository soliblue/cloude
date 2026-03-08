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

## Codex Review

**Findings (by risk)**
1. **High:** "Entire output must parse cleanly" is very safe, but may under-deliver UX. A single benign prefix/suffix (timestamps, trace text) will block rich rendering entirely. Consider whether that tradeoff is acceptable long-term.
2. **High:** XML-like parsing is fragile if implemented with regex/string slicing (multiline content, escaped `<`, nested/duplicated tags, malformed closing tags). This can cause false negatives or accidental content loss.
3. **Medium:** Incremental tag handlers can become ad hoc without a typed model/registry. You'll want a clear ownership/versioning path for new tag patterns.
4. **Medium:** No explicit mention of accessibility behavior for error rendering (contrast, Dynamic Type, VoiceOver labels).
5. **Medium:** Missing observability: track parse success/fallback rates to know whether the feature is helping or silently not activating.

**Missing considerations**
1. Test matrix: exact match, whitespace variants, malformed tags, mixed content, repeated tags, unknown tags, very large outputs.
2. Security/safety: ensure rendered content is always treated as plain text unless explicitly safe; never interpret embedded markup beyond your whitelist.
3. Performance: avoid reparsing on every SwiftUI recomposition; cache parse result from `resultOutput`.

**Suggested improvements**
1. Create a small parser utility (not inline) returning a typed result like: `.plain(raw)` or `.known(tag, payload)`.
2. Define a strict grammar per supported tag (`tool_use_error` first), with deterministic failure to `.plain(raw)`.
3. Add a handler registry so adding tags is data-driven, not `if/else` growth.
4. Add snapshot/UI tests for styled rendering and fallback behavior.
