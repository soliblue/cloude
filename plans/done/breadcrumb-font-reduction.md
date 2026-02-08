# Reduce Path Breadcrumb Font Size
<!-- priority: 10 -->
<!-- build: 56 -->

Reduced path breadcrumb font from `.caption` to `.caption2` across file viewers and folder browser.

## Changes
- `FileViewerBreadcrumb.swift` — folder segments, ellipsis, filename all `.caption2`
- `FileBrowserView+Components.swift` — pathBar text `.caption2`, chevron `.system(size: 8)`

## Scope
Both path bars share the same font size now. No duplication — `FileViewerBreadcrumb` is reused by both `FilePreviewView` and `FilePathPreviewView`.
