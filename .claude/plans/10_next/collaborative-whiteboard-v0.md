# Collaborative Whiteboard v0

Minimal viable whiteboard: a shared canvas where Soli draws by touch and Claude adds/draws elements via MCP. Triggered by `/whiteboard` slash command, opens as a full-screen sheet.

## Goals
- Canvas with pan/zoom and touch drawing
- 5 element types: rect, ellipse, text, path (freehand), arrow
- Claude reads/writes the canvas via `mcp__ios__whiteboard` tool
- Undo stack (critical since Claude edits directly)
- Virtual 0-1000 coordinate space (screen-size independent)

## Data Model

Flat JSON, minimal fields:

```json
{
  "viewport": {"x": 0, "y": 0, "zoom": 1.0},
  "elements": [
    {"id": "a", "type": "rect", "x": 100, "y": 100, "w": 120, "h": 60, "label": "Auth", "fill": "#FF6B6B", "stroke": "#333"},
    {"id": "b", "type": "ellipse", "x": 300, "y": 100, "w": 80, "h": 80},
    {"id": "c", "type": "text", "x": 200, "y": 50, "label": "Overview"},
    {"id": "d", "type": "path", "points": [[10,20],[15,30],[20,20]], "closed": false, "stroke": "#333"},
    {"id": "e", "type": "arrow", "from": "a", "to": "b", "label": "queries"}
  ]
}
```

- `fill`, `stroke`, `label`, `closed` all optional with sensible defaults
- Arrows reference element IDs via `from`/`to`
- Paths store `[[x,y], ...]` arrays (simplified with Ramer-Douglas-Peucker)
- Coordinate space: 0-1000 virtual units, mapped to screen

## Trigger & AI Interaction

`/whiteboard` slash command in GlobalInputBar. Opens `WhiteboardSheet` as a full-screen sheet AND sends a context signal to Claude so it knows the whiteboard is active. No window type changes.

**How Claude sees the board:**
- Hybrid context: when whiteboard has content, auto-include a summary line with message context (e.g. `[Whiteboard: 5 elements - Auth, DB, API, 2 arrows]`)
- Claude calls `snapshot` for full detail when it needs to reason about layout/connections
- Saves tokens vs sending full JSON every message

**How Claude edits:**
- User asks in chat: "draw the auth flow", "add a database box", "connect these two"
- Claude can proactively build diagrams while explaining (add elements as response streams)
- Claude can read user's rough sketches via snapshot and refine/label/connect them
- All edits are instant (no ghost preview/approval), undo handles mistakes

**User-to-AI flow:**
1. User opens `/whiteboard`, draws some rough boxes
2. Sends message: "clean this up and add the connections"
3. Claude snapshots the board, sees the elements, adds arrows + labels + repositions

## Gesture Strategy

Two modes toggled in toolbar: **Select** (default) and **Draw** (freehand).

**Select mode:**
- Tap empty space: show element picker (rect/ellipse/text)
- Tap element: select (show handles)
- Drag element: move
- Drag empty space: pan
- Pinch: zoom
- Long press element: delete

**Draw mode:**
- Finger drag: capture points as freehand path
- Pinch: still zoom
- Two-finger drag: still pan

Hit testing is manual (check touch coords against element frames in virtual space).

## Rendering

SwiftUI Canvas view inside GeometryReader with custom camera transform (offset + scale). All elements drawn in a single render pass. No wobbly/hand-drawn lines in v0, just clean shapes with rounded corners.

Use one top-level DragGesture + one MagnifyGesture, manage interaction state internally. If SwiftUI gesture composition gets brittle, fall back to UIViewRepresentable with custom UIGestureRecognizers.

Text editing and selection handles as SwiftUI overlays on top of canvas, not drawn into it.

## Undo

Snapshot-based: push full elements array onto stack before every mutation. Undo button pops the stack. Cap at ~50 snapshots.

## MCP Tool

`mcp__ios__whiteboard` with actions:
- **add**: `{"action": "add", "elements": [...]}` - add elements to canvas
- **remove**: `{"action": "remove", "ids": ["a", "b"]}` - remove by ID
- **update**: `{"action": "update", "id": "a", "x": 200}` - update fields on existing element
- **snapshot**: `{"action": "snapshot"}` - returns full canvas JSON
- **clear**: `{"action": "clear"}` - wipe the canvas

Claude references elements by ID. Smart label lookup (resolve "Auth" to element with that label) is nice-to-have but not v0.

## Persistence

Canvas state stored as JSON on the conversation object (like drafts). Saves on every change (debounced 0.5s). Restoring `/whiteboard` on the same conversation brings back the canvas.

## Files

New:
- `Cloude/UI/WhiteboardSheet.swift` - main canvas view + rendering
- `Cloude/UI/WhiteboardSheet+Gestures.swift` - touch handling
- `Cloude/UI/WhiteboardSheet+Toolbar.swift` - mode toggle, undo, element picker
- `Cloude/Models/WhiteboardElement.swift` - data model (Codable structs)
- `Cloude/Services/WhiteboardStore.swift` - state, undo stack, persistence

Modified:
- `GlobalInputBar+Components.swift` - add `/whiteboard` to slash suggestions
- `CloudeApp.swift` - sheet presentation for whiteboard
- MCP tool handler (relay side) - `mcp__ios__whiteboard` intercept

## Not in v0
- Wobbly/hand-drawn line aesthetic
- Ghost element accept/decline previews
- Auto-layout algorithm
- Sections/groups
- Export as image
- Multiple whiteboards per conversation
- Color picker UI (Claude sets colors, user gets defaults)

## Codex Review (GPT-5.4)

- GeometryReader + Canvas with custom camera transform is the right approach (not ScrollView)
- Gesture handling: use interaction state machine, not competing SwiftUI gestures. Hit-test at touch-down, decide intent (elementTap/elementDrag/canvasPan/drawStroke), gate by mode
- RDP tolerance: 0.25x-0.75x of stroke width in board units. Pre-pass to drop points closer than min distance
- Canvas gotchas: no per-element hit testing (manual), redraws everything on state change (keep model stable), text/handles as overlays not in canvas, large coords can jitter at extreme zoom
- May need UIViewRepresentable fallback for gestures if SwiftUI composition gets brittle

## Open Questions
- Should the element picker be a popover at tap location or a bottom toolbar?
- Path point simplification: what epsilon value for RDP feels right? (Codex suggests 0.25x-0.75x stroke width)
- Should we persist whiteboard state on the agent side (relay) or purely iOS?
