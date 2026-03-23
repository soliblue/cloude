# Whiteboard v2 {hand.draw}
<!-- priority: 8 -->
<!-- tags: widget, ui, agent, relay -->

> Evolve the whiteboard from basic shapes into a real thinking medium with sketchy rendering, groups, export, and layout.

Current implementation: ~2,400 lines across 20 files.

## File Budget (150-line rule)

Files already near limit that v2 will grow. Plan splits upfront:

| File | Now | Pressure From | Split Strategy |
|------|-----|---------------|----------------|
| `WhiteboardSheet+Drawing.swift` | 146 | sketchy, groups, annotations, images, labels, stroke/dash/opacity | Split into `+DrawShapes.swift`, `+DrawArrows.swift`, `+DrawPaths.swift`. Keep `+Drawing.swift` as dispatcher only. |
| `WhiteboardSheet+GestureHandlers.swift` | 150 | groups (multi-select), annotation mode | Split group gesture logic to `+GroupGestures.swift` if needed |
| `WhiteboardSheet+ContextBar.swift` | 147 | group/ungroup buttons, font size selector | Split to `+ContextBar+GroupActions.swift` if needed |
| `WhiteboardSheet+Toolbar.swift` | 125 | export, send snapshot, image picker, annotation toggle, page switcher | Split to `+Toolbar+Actions.swift` for action buttons |
| `WhiteboardStore+Elements.swift` | 132 | groups, regions, animation triggers | Split group logic to `WhiteboardStore+Groups.swift` |
| `WhiteboardStore+HitTesting.swift` | 113 | group selection, region containment | OK for now, monitor |
| `WhiteboardElement.swift` | 64 | many new properties | OK - properties are single lines, will grow to ~90-100 |
| `CloudeApp+WhiteboardHandling.swift` | 78 | viewport, richer snapshots, layout dispatch | OK - will grow to ~120 |
| `server.js` | 192 | already over! new tools, new params | Split whiteboard tools to `handlers-whiteboard.js` in relay |
| `WhiteboardStore.swift` | 93 | pages, presence cursor | OK for now |

## Completed (v2 session, 2026-03-23)

### Bugs fixed
- [x] Fix arrows and text not rendering via MCP
- [x] Fix shapes rendering with unwanted border
- [x] Fix arrow selection highlighting random elements (arrows have no meaningful x/y/w/h)

### File splits
- [x] Split `WhiteboardSheet+Drawing.swift` into `+DrawShapes.swift`, `+DrawArrows.swift`, `+DrawPaths.swift`
- [x] Keep `+Drawing.swift` as dispatcher only

### Core improvements
- [x] Add `z: Int?` to `WhiteboardElement`, sort by z at render time
- [x] Z-order buttons in context bar (single + multi-select)
- [x] Add `fontSize: Double?` to `WhiteboardElement`, use in text rendering
- [x] Font size selector in context bar for text elements
- [x] Add `strokeWidth: Double?`, `strokeStyle: String?`, `opacity: Double?` to `WhiteboardElement`
- [x] Apply stroke/opacity in draw methods across `+DrawShapes`, `+DrawArrows`, `+DrawPaths`
- [x] Render arrow labels at midpoint, parallel to arrow direction
- [x] Text auto-wrap and center-justified in shapes and text elements (manual word wrapping with CTFont)

### Hand-drawn aesthetic
- [x] Create `WhiteboardSheet+Sketchy.swift` with roughness algorithms (jittered control points, multi-stroke lines, seeded PRNG)
- [x] Integrate sketchy rendering into `+DrawShapes`, `+DrawArrows`, `+DrawPaths`

### Groups & multi-select
- [x] Add `groupId: String?` to `WhiteboardElement`
- [x] Add multi-select as standalone tool in bottom toolbar
- [x] Unified selection state: `selectedElementIds: Set<String>` as single source of truth, `selectedElementId` is computed
- [x] Create `WhiteboardStore+Groups.swift` with group/ungroup operations
- [x] Tap on grouped element selects whole group
- [x] Multi-select action row: count, z-order, group, ungroup, delete
- [x] Color picker applies to all selected elements in multi-select
- [x] Bulk z-order (moveForwardMany/moveBackwardMany) for multi-select
- [ ] Groups are flat (single groupId string) - no nested/hierarchical subgroups yet

### Export & snapshots
- [x] Add export button to toolbar (save to camera roll)
- [x] Create `WhiteboardSheet+Export.swift` with `ImageRenderer` -> camera roll
- [x] Add "send snapshot" button to toolbar with divider
- [x] Add `whiteboard_open` MCP tool (whiteboard no longer auto-opens on every action)
- [x] Add `whiteboard_export` MCP tool (renders to JPEG, sends as image in conversation)
- [x] Send button disabled when environment not connected

### Layout & positioning
- [x] Add `layout` param to `whiteboard_add` (tree/grid/row/column/radial)
- [x] Create `WhiteboardStore+Layout.swift` with layout algorithms
- [x] Add `relativeTo` positioning for elements (right/left/below/above with gap)

### Viewport
- [x] Add `whiteboard_viewport` tool with x/y/zoom params

### UI polish
- [x] Removed sheet title "Whiteboard"
- [x] Whiteboard tool pills in chat are tappable (open whiteboard via NotificationCenter)
- [x] Cleaner display names for whiteboard tools ("Add", "Remove", "Clear" etc.)

### Refactoring
- [x] Dual selection state collapsed to single `selectedElementIds` source of truth
- [x] `selectedIds` computed property simplified
- [x] `removeElement`/`removeElements` clean up selection state properly

## Remaining (future)

### Regions & references
- [ ] Add `region` type or `isContainer: Bool` to `WhiteboardElement`
- [ ] Render regions as dashed/translucent background rects
- [ ] Auto-associate elements inside region bounds, move with region
- [ ] Add `messageId: String?` to `WhiteboardElement` for conversation references

### Annotation layer
- [ ] Add `layer: String?` (base/annotation) to `WhiteboardElement`
- [ ] Render annotation elements with different visual treatment
- [ ] Add annotation mode toggle to toolbar

### Nested groups
- [ ] Hierarchical group support (parentGroupId chain or tree structure)
- [ ] UX for which level gets selected/moved on tap

### Whiteboard-first mode (stretch)
- [ ] Embed lightweight input bar in `WhiteboardSheet.swift`
- [ ] Create `WhiteboardSheet+ResponseOverlay.swift` for AI response toasts
- [ ] Add entrance animations for new elements

### Bigger ideas (stretch)
- [ ] Image element type with async loading and Canvas rendering
- [ ] Multiple pages/whiteboards with tab switching
- [ ] AI cursor presence trail
- [ ] Richer snapshot modes (format: json/image/both)

## Open
- Flat groups vs nested: user wants to sleep on whether hierarchical groups add value or just confusion (which level moves on tap?)
