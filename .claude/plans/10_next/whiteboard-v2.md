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

## Bugs

### Arrows and text not rendering via MCP
Elements silently dropped on `whiteboard_add` - only rects/ellipses survive.
- **Trace**: `server.js` (MCP returns IDs) -> relay `handlers.js` -> `CloudeApp+WhiteboardHandling.swift:handleWhiteboardAction()` (decode) -> `WhiteboardStore+Elements.swift:addElements()` -> `WhiteboardSheet+Drawing.swift:drawElement()`
- **Files to debug**: `CloudeApp+WhiteboardHandling.swift` (JSON decoding may fail silently for arrow/text types), `WhiteboardElement.swift` (Codable conformance for all types)

### Shapes render with unwanted border
Rects/ellipses show a visible stroke when they shouldn't by default.
- **File**: `WhiteboardSheet+Drawing.swift:drawShape()` - currently draws both fill + stroke. Should only stroke if `stroke` property is explicitly set.

## Improvements

### Hand-drawn aesthetic (Excalidraw style)
Wobbly edges, sketchy lines, imperfect shapes. rough.js-style algorithms adapted for SwiftUI Canvas.
- **New**: `WhiteboardSheet+Sketchy.swift` (~100 lines) - roughness algorithms: jittered control points, multi-stroke lines, hand-drawn arcs. Parameterized by a `roughness` value.
- **Edit**: `WhiteboardSheet+DrawShapes.swift` (split from Drawing) - call sketchy helpers instead of clean paths
- **Edit**: `WhiteboardSheet+DrawArrows.swift` (split from Drawing) - wobbly arrow lines
- **Edit**: `WhiteboardSheet+DrawPaths.swift` (split from Drawing) - sketchy path rendering

### Z-ordering via MCP
`z` property on elements, sorted at render time.
- **Edit**: `WhiteboardElement.swift` - add `z: Int?` property
- **Edit**: `WhiteboardStore+Elements.swift` - sort by `z` in element accessors, expose `bringToFront()`/`sendToBack()` that set z values
- **Edit**: `handlers-whiteboard.js` - add `z` to element schema
- **Edit**: `CloudeApp+WhiteboardHandling.swift` - pass through `z` on add/update

### Export as image
Toolbar button to render canvas to PNG, save to camera roll.
- **Edit**: `WhiteboardSheet+Toolbar.swift` - add export button
- **New**: `WhiteboardSheet+Export.swift` (~50 lines) - use `ImageRenderer` on the Canvas content, save via `UIImageWriteToSavedPhotosAlbum`

### Send snapshot button (user-triggered)
Toolbar button that sends canvas state into the conversation.
- **Edit**: `WhiteboardSheet+Toolbar.swift` - add "send" button
- **Edit**: `WhiteboardSheet.swift` - needs callback to parent to inject message into conversation
- **Edit**: `CloudeApp+WhiteboardHandling.swift` - reuse existing snapshot logic but triggered from UI instead of MCP

### Richer snapshot modes (image + JSON)
`whiteboard_snapshot` gets `format` param: `json`, `image`, `both`.
- **Edit**: `handlers-whiteboard.js` - add `format` param to `whiteboard_snapshot` tool schema
- **Edit**: `CloudeApp+WhiteboardHandling.swift` - render Canvas to image when format includes `image`, encode as base64 or save + reference
- **Edit**: `WhiteboardSheet+Export.swift` - shared render-to-image logic used by both export and snapshot

### Groups
Select multiple elements, treat as one unit.
- **Edit**: `WhiteboardElement.swift` - add `groupId: String?` property
- **Edit**: `WhiteboardStore.swift` - add `@Published var selectedElementIds: Set<String>` (multi-select)
- **New**: `WhiteboardStore+Groups.swift` (~80 lines) - group/ungroup operations, move/delete by group, split from Elements
- **Edit**: `WhiteboardStore+HitTesting.swift` - tap on grouped element selects whole group
- **Edit**: `WhiteboardSheet+GestureHandlers.swift` - multi-select gesture (long press + tap to add?)
- **Edit**: `WhiteboardSheet+ContextBar.swift` - group/ungroup buttons when multiple selected
- **Edit**: `WhiteboardSheet+DrawShapes.swift` - group outline overlay

### Element labels inside shapes
Rects/ellipses already support `label` - ensure it renders centered and clean.
- **Edit**: `WhiteboardSheet+DrawShapes.swift` - verify text centering, adjust font to fit bounds, truncate if needed

### Font size / text styling
`size` param on text elements (small/medium/large or numeric).
- **Edit**: `WhiteboardElement.swift` - add `fontSize: Double?` property
- **Edit**: `WhiteboardSheet+DrawShapes.swift` - use fontSize when rendering text elements
- **Edit**: `handlers-whiteboard.js` - add `fontSize` to element schema
- **Edit**: `WhiteboardSheet+ContextBar.swift` - font size selector when text element selected

### Arrow labels
Arrows carry a `label` rendered at midpoint.
- **Edit**: `WhiteboardSheet+DrawArrows.swift` - render label text at arrow midpoint, offset slightly above the line
- Already supported in `WhiteboardElement.swift` (label property exists on all elements)
- **Edit**: `handlers-whiteboard.js` - document that `label` works on arrows

### Layout hints
`layout` param on `whiteboard_add` - `tree`, `grid`, `row`, `column`, `radial` - auto-positions elements.
- **Edit**: `handlers-whiteboard.js` - add `layout` param with `root` (x,y), `type`, and `spacing` to `whiteboard_add`
- **New**: `WhiteboardStore+Layout.swift` (~150 lines) - layout algorithms: tree (recursive positioning), grid (rows x cols), row/column (linear), radial (angle-spaced around center)
- **Edit**: `CloudeApp+WhiteboardHandling.swift` - detect layout param, run layout before adding elements

### Stroke width, dashed lines, opacity
New element properties: `strokeWidth: Double?`, `strokeStyle: String?` (solid/dashed/dotted), `opacity: Double?`.
- **Edit**: `WhiteboardElement.swift` - add all three properties
- **Edit**: `WhiteboardSheet+DrawShapes.swift`, `+DrawArrows.swift`, `+DrawPaths.swift` - apply in draw methods
- **Edit**: `handlers-whiteboard.js` (new, split from `server.js`) - add to schema

### Viewport control
MCP tool to set camera position/zoom.
- **Edit**: `handlers-whiteboard.js` - new `whiteboard_viewport` tool with `x`, `y`, `zoom` params
- **Edit**: `CloudeApp+WhiteboardHandling.swift` - handle `"viewport"` action, update `store.state.viewport`
- **Edit**: `WhiteboardStore.swift` - `setViewport()` with animation

### Annotation layer
Mode where new elements are overlay annotations (different visual treatment).
- **Edit**: `WhiteboardElement.swift` - add `layer: String?` (`base` / `annotation`)
- **Edit**: `WhiteboardSheet+DrawShapes.swift` - annotation elements render with slight transparency and different stroke style
- **Edit**: `WhiteboardSheet+Toolbar.swift` - toggle annotation mode

### Regions / containers
Elements that visually scope other elements.
- **Edit**: `WhiteboardElement.swift` - new type `region` or use rect with `isContainer: Bool`
- **Edit**: `WhiteboardSheet+DrawShapes.swift` - render regions as dashed/translucent background rects
- **Edit**: `WhiteboardStore+Elements.swift` - elements inside region bounds auto-associate, move with region
- **Edit**: `WhiteboardStore+HitTesting.swift` - containment logic

### Conversation references
Elements link back to chat messages.
- **Edit**: `WhiteboardElement.swift` - add `messageId: String?`
- **Edit**: `WhiteboardSheet+DrawShapes.swift` - small link icon on elements with references
- **Edit**: `WhiteboardSheet+GestureHandlers.swift` - tap on link icon navigates to message in chat

## Whiteboard-First Mode

The whiteboard becomes the primary view, chat becomes overlay.

### Floating input bar
- **Edit**: `WhiteboardSheet.swift` - embed a lightweight input bar at the bottom (above toolbar)
- **Reuse**: `GlobalInputBar.swift` architecture but stripped down - text field + send button only
- On send: auto-attach canvas snapshot as context

### AI response toasts
- **New**: `WhiteboardSheet+ResponseOverlay.swift` (~80 lines) - dismissible card in top-right corner showing latest AI text response. Auto-dismiss after ~10s or tap to dismiss. Queue if multiple responses arrive.

### Live element appearance
- **Edit**: `WhiteboardStore+Elements.swift:addElements()` - trigger entrance animation per element
- **Edit**: `WhiteboardSheet.swift` - animate new elements with fade-in + slight scale via Canvas redraw

## Bigger Ideas

### Images on canvas
New element type `image` with URL or base64 source.
- **Edit**: `WhiteboardElement.swift` - add `image` to type enum, add `imageSource: String?`
- **New**: `WhiteboardSheet+DrawImages.swift` (~80 lines) - async image loading, render in Canvas
- **Edit**: `WhiteboardSheet+Drawing.swift` - dispatch to image renderer (alongside shapes/arrows/paths)
- **Edit**: `handlers-whiteboard.js` - add `image` type with `imageSource` param
- **Edit**: `WhiteboardSheet+Toolbar.swift` - image picker button

### Multiple whiteboards / pages
One canvas per topic, switch like tabs.
- **Edit**: `WhiteboardStore.swift` - manage multiple `WhiteboardState` instances, `activePageId`
- **Edit**: `WhiteboardStore+Persistence.swift` - save/load per page within conversation
- **New**: `WhiteboardSheet+PageSwitcher.swift` (~60 lines) - horizontal pill bar or swipe to switch pages
- **Edit**: `handlers-whiteboard.js` - `page` param on all whiteboard tools

### Presence / live drawing
AI cursor trail, element appearance animation.
- **Edit**: `WhiteboardStore.swift` - `@Published var aiCursorPosition: CGPoint?`
- **Edit**: `WhiteboardSheet+Drawing.swift` - render AI cursor as a subtle animated dot (in dispatcher)
- **Edit**: `CloudeApp+WhiteboardHandling.swift` - emit cursor position hints during batch adds

## Workflows (no new primitives needed)
- Sketch-to-structure: user draws rough shapes by hand -> AI requests image snapshot -> interprets the sketch -> clears and redraws with clean structured elements. Requires: image snapshot mode working.

## Open
- Discovered through use, not planned upfront. Add here as friction surfaces.
