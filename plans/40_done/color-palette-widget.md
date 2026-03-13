# Color Palette Widget

New MCP widget for displaying color swatches in chat.

## Changes
- `widgets-mcp/server.js`: Added `color_palette` tool definition
- `WidgetView+ColorPalette.swift`: SwiftUI view with stacked color rows (swatch + hex + label)
- `WidgetView+Registry.swift`: Registered with `paintpalette` icon, purple accent
