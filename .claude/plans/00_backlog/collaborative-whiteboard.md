# Collaborative Whiteboard

A shared visual thinking space in the iOS app. Soli draws by touch, Claude participates via MCP tools. A new medium for thinking together beyond text.

## Background

Architecture discussions happen in text, but systems are visual. Mermaid diagrams render as raw code blocks. What's needed isn't a diagram renderer but a collaborative canvas where both participants can place, connect, and rearrange ideas visually.

Inspired by Excalidraw: hand-drawn aesthetic, simple primitives, infinite canvas. But mobile-native and with an AI participant.

## Goals

- Infinite canvas with pan/zoom, hand-drawn visual style
- Primitives: rectangles, ellipses, arrows, text labels, freehand lines, sections/groups
- Touch-native: tap to place, drag to move, pinch to zoom, long press to edit
- Claude participates via MCP tools that propose edits (accept/decline model)
- Claude reads board state as JSON snapshot (not screenshots)
- Sections can contain other elements (nested grouping)
- Arrows snap to shapes and stay connected when dragged

## Architecture

### Data Model

```swift
struct Whiteboard: Codable, Identifiable {
    let id: UUID
    var name: String
    var elements: [WhiteboardElement]
    var viewport: Viewport  // current pan/zoom state
}

struct WhiteboardElement: Codable, Identifiable {
    let id: String
    var kind: ElementKind
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var label: String
    var style: ElementStyle
    var parentId: String?      // for grouping (element lives inside a section)
    var connections: [Connection]
}

enum ElementKind: String, Codable {
    case rectangle, ellipse, text, arrow, freehand, section
}

struct Connection: Codable {
    let targetId: String
    var label: String?
    var style: ArrowStyle?
}

struct ElementStyle: Codable {
    var fillColor: String?     // hex
    var strokeColor: String?   // hex
    var strokeWidth: Double?
    var fontSize: Double?
    var opacity: Double?
}

struct Viewport: Codable {
    var offsetX: Double
    var offsetY: Double
    var scale: Double
}
```

### App Integration

New `WindowType.whiteboard` alongside chat, files, git, terminal:

```
ChatWindow.swift     → add .whiteboard case
MainChatView+Windows → add WhiteboardView case to switch
```

User switches to whiteboard via the window type buttons in the header. Each window can be a whiteboard, same as it can be a file browser or terminal.

### Rendering

SwiftUI `Canvas` view for performant drawing of all elements on an infinite plane.

**Hand-drawn aesthetic**: Instead of roughjs (JS library), implement a simple "wobbly line" function that adds slight randomness to path control points. A line from A to B becomes a bezier with slightly offset control points. Rectangles become four wobbly lines. This is ~30 lines of code, not a library.

```swift
func wobblyPath(from: CGPoint, to: CGPoint, seed: UInt64) -> Path {
    // Add slight perpendicular offset to midpoint based on seed
    // Creates the hand-drawn feel without any JS dependency
}
```

Arrows: bezier curves with arrowhead at the end. Snap to nearest edge of connected shapes.

### Touch Interaction

| Gesture | Action |
|---------|--------|
| Tap empty space | Place new element (shows picker: rect/ellipse/text/section) |
| Tap element | Select it (shows handles) |
| Drag element | Move it (connected arrows follow) |
| Drag handle | Resize |
| Pinch | Zoom canvas |
| Two-finger drag | Pan canvas |
| Long press element | Edit label, style, delete |
| Draw gesture (finger drag on empty space) | Freehand line |

Mode toggle in toolbar: **Select** vs **Draw** (freehand). Default is Select.

### MCP Integration

Single MCP tool: `mcp__ios__whiteboard`

```json
{
    "action": "add",
    "elements": [
        {"kind": "rectangle", "label": "Auth Service", "x": 100, "y": 100},
        {"kind": "rectangle", "label": "Database", "x": 300, "y": 100},
        {"kind": "arrow", "from": "Auth Service", "to": "Database", "label": "queries"}
    ]
}
```

Actions:
- **add** - propose adding elements (user sees them appear with accept/decline)
- **move** - propose moving elements
- **connect** - propose new connections
- **remove** - propose removing elements
- **label** - propose label changes
- **snapshot** - returns full board state as JSON (no approval needed)
- **clear** - propose clearing the board
- **layout** - auto-arrange all elements (simple force-directed or rank-based)

**Accept/decline flow**: When Claude proposes changes, they appear as "ghost" elements (dimmed/dashed outline) with an accept/decline banner at the top. Like a visual diff. Soli taps accept to commit them or decline to discard. This reuses the same pattern as the question/approval UI in ConversationView.

**Smart addressing**: Claude can reference elements by label (not just ID), so `"from": "Auth Service"` resolves to the element with that label. Makes MCP calls readable.

### Persistence & Lifecycle

Each conversation has an optional whiteboard. The whiteboard state (all elements + viewport) serializes to JSON and is stored as part of the conversation data.

**Lifecycle**:
- Whiteboard is created when the user first switches a window to `.whiteboard` type
- State saves automatically on every change (debounced, like how drafts work)
- Switching away from the whiteboard window type preserves the state silently
- Switching back restores it exactly as it was
- Whiteboard lives as long as the conversation lives

**Claude's access**:
- Claude can call `snapshot` at any time to get current board state as JSON, even if the user isn't viewing the whiteboard right now
- The iOS app can also proactively include the whiteboard state as context when sending a message, if the whiteboard has content. This way Claude always knows what's on the board without having to ask
- When Claude proposes edits while the user is NOT on the whiteboard view, the app queues the proposal. Next time the user opens the whiteboard, they see the pending ghost elements to accept/decline
- If Claude proposes edits while streaming, the app queues them and presents after the response completes (same as how question prompts work)

### Auto-Layout

For when Claude places a batch of nodes and connections, a simple layout algorithm positions them:

1. **Rank assignment**: BFS from root nodes, assign layers
2. **Ordering**: Minimize crossings within layers (simple heuristic: sort by connection density)
3. **Positioning**: Equal spacing within layers, centered
4. **Direction**: Left-to-right or top-to-bottom (configurable)

This runs when Claude uses the `layout` action, or when adding multiple connected elements at once. User can always drag things after.

## Phases

### Phase 1: Canvas + Static Elements
- WhiteboardView with Canvas rendering
- Pan/zoom with gestures
- Add/select/move/resize rectangles and ellipses
- Wobbly hand-drawn line rendering
- Text labels on shapes
- Persistence to JSON

### Phase 2: Arrows + Sections
- Arrow connections between shapes (snap to edges)
- Sections/groups that contain child elements
- Freehand drawing mode
- Long press to edit/delete

### Phase 3: MCP Integration
- `mcp__ios__whiteboard` tool
- Ghost element preview with accept/decline
- Snapshot returns board state as JSON
- Smart label-based addressing

### Phase 4: Auto-Layout + Polish
- Layout algorithm for batch placements
- Undo/redo
- Export as image
- Color palette aligned with app theme

## Files

New:
- `WhiteboardView.swift` - main canvas view
- `WhiteboardView+Gestures.swift` - touch handling
- `WhiteboardView+Rendering.swift` - Canvas drawing + wobbly paths
- `WhiteboardView+Toolbar.swift` - mode toggle, element picker
- `WhiteboardElement.swift` - data model (in Models/)
- `WhiteboardStore.swift` - persistence + state management (in Services/)

Modified:
- `ChatWindow.swift` - add `.whiteboard` to WindowType
- `MainChatView+Windows.swift` - add WhiteboardView case

## Open Questions

- Should freehand lines auto-smooth into curves, or stay raw?
- Should we support multiple whiteboards per conversation or one is enough?
- Color picker: predefined palette or full picker?
- Should Claude be able to add elements without approval in some "trusted" mode?
