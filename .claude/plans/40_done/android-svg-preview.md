# Android SVG Preview {doc.richtext}
<!-- priority: 13 -->
<!-- tags: android, files, ui -->

> Render SVG files as images instead of showing raw XML in file preview.

## Context
SVG files currently display as syntax-highlighted XML text. iOS renders SVGs visually. Android should do the same.

## Options
- **AndroidSVG** (`com.caverock:androidsvg-aar`): lightweight, renders SVG to Canvas/Bitmap. No additional native dependencies.
- **Coil + SVG decoder** (`io.coil-kt:coil-svg`): if Coil is already a dependency, just add the SVG decoder.
- **Custom WebView**: render SVG in a small WebView. Heavy but handles complex SVGs well.

## Implementation notes
- Detect `.svg` extension in FileViewerSheet
- Decode base64 bytes to string (SVG is text-based)
- Parse with AndroidSVG or Coil, render to Bitmap, display with `Image` composable
- Fall back to XML text view if SVG parsing fails
