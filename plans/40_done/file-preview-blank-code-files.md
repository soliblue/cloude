# Fix: Blank file preview for code files
<!-- priority: 10 -->
<!-- tags: files, ui -->
<!-- build: 56 -->

## Problem
Opening Swift (and other code) files in the file preview showed a completely blank content area. The path breadcrumb was visible but no code was rendered.

## Root Cause
`richContentView` was called for ALL content types. For `.code` files, the `default` branch in the switch produced an empty-but-non-nil view from `@ViewBuilder`, so `if let richView` succeeded and rendered nothing — preventing fallback to `sourceTextView`.

## Fix
- Gated `renderedView` call on `contentType.hasRenderedView` (now `hasRenderedView`) — only markdown, JSON, YAML, CSV, HTML
- Code files now go straight to syntax-highlighted source view

## Architecture Cleanup
- Renamed `hasRichView` → `hasRenderedView`, `showRichSource` → `showSource`, `richContentView` → `renderedView`
- Simplified `fileContent` flow: image → text-based (rendered or source) → binary
- `renderedView` returns `nil` for types without a rendered alternative, naturally falling through to source

## Files Changed
- `FilePathPreviewView+Content.swift` — restructured content flow, renamed function
- `FilePathPreviewView.swift` — renamed state var
- `FileContentType.swift` — renamed property
