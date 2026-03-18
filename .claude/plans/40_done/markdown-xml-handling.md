# Markdown XML Tag Handling

Agent tool results (and other tool outputs) contain XML tags like `<usage>`, `<system-reminder>`, etc. mixed into markdown content. Currently these render as raw visible text in `StreamingMarkdownView`.

## Goals
- XML blocks outside code fences render as styled inline blocks (like code blocks but for XML)
- Tag name shown as a small label (like the language label on code blocks)
- Content inside rendered as dimmed monospaced text
- Self-closing tags (`<tag />`) rendered as a single-line styled element
- XML inside code blocks / backticks stays untouched

## Approach
1. **Markdown parser**: detect `<tag>...</tag>` and `<tag ... />` outside code blocks, emit as new `StreamingBlock` case (e.g. `.xml(tagName, content)`)
2. **Block view**: render like a code block but visually distinct - tag name label, dimmed monospaced content, slightly different background
3. Code fences already skip parsing, so XML in code is safe
4. Nested XML inside the block just renders as part of the content text (no recursive parsing needed for v1)

## Files
- `StreamingMarkdownView.swift` - parser: new block type detection
- `MarkdownText+Blocks.swift` - new XMLBlock view

## Open Questions
- Color/style for XML blocks? Maybe same as code blocks but with a tinted label
