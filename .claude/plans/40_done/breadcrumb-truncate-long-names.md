# Breadcrumb: Truncate Long Path Components {scissors}
<!-- priority: 10 -->
<!-- tags: ui, file-preview -->
<!-- build: 56 -->

> Truncated each breadcrumb path component at 20 characters to prevent overflow.

**Problem**: File viewer breadcrumb overflows when a directory or filename is very long.

**Fix**: Each path component truncates at 20 characters with `…` suffix. Applies to both directory segments and the final filename.

**File**: `Cloude/Cloude/UI/FileViewerBreadcrumb.swift`
