---
title: "Android File Preview v2"
description: "HTML rendered preview and animated GIF support in file viewer."
created_at: 2026-04-03
tags: ["android", "files", "ui"]
build: 125
icon: doc.viewfinder
---
# Android File Preview v2


## Context

iOS renders HTML files in a WKWebView (JS disabled) with a source/rendered toggle, and animates GIF files frame-by-frame. Android currently shows HTML as raw text and GIFs as static images.

## Scope

### HTML Rendered Preview
- Detect `.html`/`.htm` files in file preview
- Render in Android WebView with JavaScript disabled
- Toggle button to switch between rendered view and source code view
- Sandboxed: no network access, local content only

### Animated GIF Support
- Use Coil's GIF decoder or android-gif-drawable library
- Animate GIFs in both file preview and inline message images
- Support loop control

## Implementation

- HTML: `WebView` composable with `WebViewClient`, load content via `loadDataWithBaseURL`
- GIF: Add `io.coil-kt:coil-gif` dependency, register `ImageDecoderDecoder` in Coil

## Dependencies

- Existing file preview system (already handles content type routing)
