# Collaborative Whiteboard v0 {pencil.and.scribble}
<!-- priority: 10 -->
<!-- tags: ui, widget -->

> Built shared whiteboard canvas with touch drawing, 5 element types, MCP tools for Claude to draw, undo/redo, and per-conversation persistence.

Shared canvas where Soli draws by touch and Claude adds/draws elements via MCP tools. `/whiteboard` slash command opens as fullScreenCover.

## Shipped

### Canvas & Rendering
- SwiftUI Canvas with custom camera transform (offset + scale)
- Virtual 0-1000 coordinate space, mapped to screen
- Grid overlay (50-unit spacing)
- 5 element types: rect, ellipse, text, path (freehand), arrow
- Shapes rendered with fill color + stroke, labels centered
- Arrows connect elements by ID with arrowhead rendering
- Selection overlay (dashed border on selected element)

### Touch Interaction
- UIViewRepresentable with UIKit gesture recognizers (tap, double-tap, pan, two-finger pan, pinch)
- 6 tools in floating toolbar: Hand, Rect, Ellipse, Text, Pencil, Arrow
- Hand mode: tap to select, drag to move, pinch selected to resize
- Shape tools: tap to place, drag to size
- Text tool: tap to place, inline text editing in context bar
- Pencil: freehand drawing with distance threshold (2pt min), RDP path simplification on end
- Arrow tool: tap source element ("From" overlay), tap target to create arrow
- Double-tap any element to edit its label
- Two-finger drag to pan, pinch to zoom (0.3x-5.0x)

### Context Bar (appears when element selected)
- Color row: 6 palette colors, applies fill (shapes) or stroke (paths/text)
- Action row: layer up/down, shape morph (rect/ellipse toggle), edit label, duplicate, delete
- Inline text field with auto-focus keyboard on edit

### MCP Integration (Claude can draw)
- 5 separate tools: `whiteboard_add`, `whiteboard_remove`, `whiteboard_update`, `whiteboard_clear`, `whiteboard_snapshot`
- Each tool has structured input schema
- Auto-opens whiteboard on any MCP action
- Snapshot sends full canvas JSON back as user message (reuses screenshot pattern)
- Batch operations: single undo snapshot for multi-element add/remove
- `updateElement` method on store keeps encapsulation clean

### Undo/Redo
- Snapshot-based: full elements array pushed before every mutation
- 50 level cap
- Undo/redo buttons in navigation bar

### Persistence
- Auto-saves canvas state per conversation ID (debounced 500ms)
- Stored as JSON in app documents: `whiteboards/{conversationId}.json`
- Loads on `/whiteboard` open or MCP action
- Undo/redo history resets on reload, canvas state persists

### Code Quality (3x simplify passes)
- Batch `addElements`/`removeElements` methods (single undo push)
- `updateElement` method replaces direct state mutation (removed `pushUndoPublic`)
- Merged rect/ellipse drawing into single case
- Arrow rendering uses `[String: WhiteboardElement]` dict for O(1) lookups
- `canMoveForward`/`canMoveBackward` moved to store (single source of truth)
- Pencil distance threshold (2pt) cuts 60-80% of raw points

## Files

New:
- `Cloude/UI/WhiteboardSheet.swift` - canvas view + rendering + overlays
- `Cloude/UI/WhiteboardSheet+Gestures.swift` - UIKit gesture handling
- `Cloude/UI/WhiteboardSheet+Toolbar.swift` - floating toolbar + context bar
- `Cloude/Models/WhiteboardElement.swift` - data model (Codable structs)
- `Cloude/Services/WhiteboardStore.swift` - state, undo, persistence, arrow creation

Modified:
- `CloudeApp.swift` - whiteboardStore, fullScreenCover presentation, load on open
- `CloudeApp+EventHandling.swift` - whiteboard event handling (add/remove/update/clear/snapshot)
- `ConnectionEvent.swift` - `.whiteboard` case
- `EnvironmentConnection+Handlers.swift` - whiteboard tool interception
- `MainChatView.swift` / `MainChatView+Messaging.swift` - `/whiteboard` command routing
- `SlashCommand.swift` - `/whiteboard` in suggestions
- `.claude/ios-mcp/server.js` - 5 whiteboard MCP tool registrations

## Future
- Context signal: auto-include whiteboard summary in messages
- Export as image
- Wobbly/hand-drawn line aesthetic
- Auto-layout algorithm
- Multiple whiteboards per conversation
