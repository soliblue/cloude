---
title: "Whiteboard Refactor v1"
description: "Refactored whiteboard architecture with transaction pattern, DRY helpers, bug fixes for paths/ellipses/arrows, and MCP parity."
created_at: 2026-03-21
tags: ["refactor", "ui"]
icon: pencil.and.ruler
build: 103
---


# Whiteboard Refactor v1 {pencil.and.ruler}
## Changes

### Architecture
- Transaction pattern: `beginTransaction`/`commitTransaction` for gesture sessions (single undo snapshot per gesture, not per frame)
- `mutateElement(id:_:)` helper DRYs 4 store methods
- `scale(for:)` helper replaces 6 duplicate formula expressions
- Element factory methods on store (`beginShape`, `beginPath`, `createText`) replace inline creation in gesture handlers
- All gesture mutations routed through store methods (`moveElementDirect`, `resizeElementDirect`, `appendPathPoint`, etc.) instead of direct `store.state.elements[index]` mutation from view layer
- Path simplification (Ramer-Douglas-Peucker) moved from view to store
- `screenFrame(for:)` helper deduplicates overlay frame calculation
- Coordinate transforms simplified (viewport param removed, reads from state)
- Dead `import Combine` removed
- `drawElement` split into `drawShape`, `drawText`, `drawPath`, `drawArrow`

### Bug Fixes
- Path dragging now translates all points (was updating unused x/y fields)
- Ellipse hit testing uses proper ellipse equation (was using bounding box)
- Text elements created with small hit box (w:10, h:16) instead of default 100x60
- Arrow cascade delete: removing an element removes connected arrows
- Arrows now hittable and selectable (distance-to-segment test)

### UX
- Pinch always zooms canvas (removed confusing pinch-to-resize-selected behavior)

### MCP Parity
- Shared `elementProperties` schema between `whiteboard_add` and `whiteboard_update`
- `whiteboard_update` now supports: `points`, `closed`, `from`, `to`, `type`
- Event handler passes new fields through to store
- Updated tool descriptions (cascade delete, created IDs)

## Known Bugs
- **Arrows and text not rendering**: When adding mixed element types in a single `whiteboard_add` call, arrows and text elements are silently dropped. Only rects and ellipses survive. Reproduced by drawing the architecture diagram - first batch lost all arrows/text, second batch (arrows + text only) also didn't render. Likely a deserialization or store insertion issue for non-shape element types.

## Files Modified
- `Services/WhiteboardStore.swift` - major rewrite
- `UI/WhiteboardSheet.swift` - drawElement split, overlay dedup
- `UI/WhiteboardSheet+Gestures.swift` - full rewrite using store methods
- `App/CloudeApp+EventHandling.swift` - new updateElement fields
- `.claude/ios-mcp/server.js` - shared schema, update parity
