# Native Markdown Rendering

**Status**: Next
**Created**: 2026-02-10

## Goal
Make the markdown renderer progressively smarter — rendering richer, more interactive native UI from standard (and extended) markdown. No new protocol needed. Claude writes markdown, iOS renders it beautifully.

## Philosophy
- **Markdown is the protocol** — no cloude commands or fake tool calls for inline content
- **Progressive enhancement** — unrecognized blocks still render as code/text (graceful degradation)
- **Three layers**: markdown = rendering, chat input = responses, cloude commands = side effects
- **Blocks are self-describing** — each JSON block declares its own interactivity model

## Interactivity Model

Every extended markdown block has an `interactive` field that tells the renderer what to do:

### `"none"` — Read-only
Pure rendering. No state, no interaction beyond inspect/zoom.
```json
{"type": "bar", "interactive": "none", "title": "Activity", "data": [...]}
```

### `"local"` — Self-contained
Interactive but state lives in the view. Nothing is sent back to Claude.
```json
{"type": "flashcards", "interactive": "local", "cards": [{"front": "Capital of Egypt?", "back": "Cairo"}]}
```
Examples: flashcard flip/swipe, table sorting, image gallery swiping, expandable tree navigation.

### `"respond"` — Triggers a message
Interaction sends a chat message. `format` templates the response.
```json
{"type": "poll", "interactive": "respond", "format": "Which approach? {selection}", "q": "Which approach?", "options": ["A: Fast", "B: Simple"]}
```
```json
{"type": "rate", "interactive": "respond", "format": "Rating: {value}/5", "q": "How was this?", "max": 5}
```
The `{...}` placeholders get filled by the interaction (selection, value, etc.) and sent as the next user message.

## Block Types

### Read-only (`interactive: none`)

**Charts** — ` ```chart `
```json
{"type": "bar", "interactive": "none", "title": "Activity", "data": [{"x": "Feb 1", "y": 45}]}
```
- Reuse `InteractiveBarChart` (already built)
- Support: bar, line, area. Pie later.
- Tap-to-inspect is local, not a response

**Diffs** — ` ```diff `
- Standard markdown language tag, no JSON needed
- Render with red/green coloring, line numbers
- Reuse `GitDiffView+Components.swift:DiffTextView`

**Mermaid Diagrams** — ` ```mermaid `
- Standard extension, widely supported
- Render flowcharts, sequence diagrams, state machines

### Self-contained (`interactive: local`)

**Flashcards** — ` ```flashcards `
```json
{"type": "flashcards", "interactive": "local", "cards": [{"front": "...", "back": "..."}]}
```
- Swipe through cards, tap to flip
- Track progress locally (3/10 correct)
- Great for language learning, study sessions

**Better Tables**
- Existing markdown tables, smarter rendering
- Sortable columns, horizontal scroll, alternating rows
- Sorting/filtering is local state

**Image Gallery**
- Multiple images in a swipeable grid/carousel
- Pinch to zoom, swipe between images
- Local navigation

**Inline Media** (file paths)
- Already works — paths render as pills
- Improve: audio → inline waveform player, video → inline player
- Playback controls are local state

### Response-triggering (`interactive: respond`)

**Polls** — ` ```poll `
```json
{"type": "poll", "interactive": "respond", "format": "{selection}", "q": "Which approach?", "options": ["A: Fast but complex", "B: Simple but slow"]}
```
- Renders as tappable cards
- Tap sends formatted selection as next message
- After selection: highlight chosen, gray out others

**Confirmations** — ` ```confirm `
```json
{"type": "confirm", "interactive": "respond", "format": "{selection}", "q": "Deploy to TestFlight?", "options": ["Yes", "No"]}
```
- Binary choice, two buttons

**Ratings** — ` ```rate `
```json
{"type": "rate", "interactive": "respond", "format": "Rating: {value}/5", "q": "How did this session feel?", "max": 5}
```
- Star rating, tap sends number

## Implementation Plan

### Step 1: Code Block Router
In `StreamingMarkdownView`, detect language tags on code blocks:
- `chart`, `flashcards`, `poll`, `confirm`, `rate`, `mermaid`, `diff` → route to native renderer
- Everything else → existing syntax-highlighted code block
- Parse JSON, read `interactive` field to determine behavior

### Step 2: Interactive Block Protocol
```swift
enum BlockInteractivity {
    case none
    case local
    case respond(format: String, send: (String) -> Void)
}
```
- `respond` blocks need a closure to send a message
- Pass the conversation's send function down from the chat view
- After responding: animate the block (highlight selected, disable further interaction)

### Step 3: Chart Renderer (first `none` block)
- Parse JSON from chart code block
- Create `ChartBlockView` wrapping `InteractiveBarChart`

### Step 4: Poll Renderer (first `respond` block)
- Parse JSON, render options as tappable cards
- On tap: fill `format` template, send as message

### Step 5: Flashcard Renderer (first `local` block)
- Parse JSON, render card stack with flip animation
- Local state only — no messages sent

### Step 6: CLAUDE.md Instructions
- Document block types, JSON schemas, interactive modes
- When to use each type
- Examples Claude can copy

## Architecture
```
Markdown text
  → StreamingMarkdownParser (existing)
    → Code block with language tag
      → Parse JSON, read "interactive" field
      → "none"    → render-only view
      → "local"   → stateful view, no message sending
      → "respond" → stateful view + send closure
      → unknown   → CodeBlock (existing, graceful fallback)
    → Table → MarkdownTableView (improved sorting/scrolling)
    → File path → FilePathPill (improved with inline players)
    → diff → DiffBlockView (no JSON, just diff syntax)
    → mermaid → MermaidBlockView (no JSON, just mermaid syntax)
```

## What NOT to Build
- No general "render any SwiftUI" system — too complex, too dangerous
- No new cloude commands for inline content — markdown is the protocol
- No server-side rendering — everything native on iOS
- No persistent state across messages — each block is self-contained
