# Breadcrumb: Truncate Long Path Components
<!-- priority: 3 -->

**Problem**: File viewer breadcrumb overflows when a directory or filename is very long.

**Fix**: Each path component truncates at 20 characters with `…` suffix. Applies to both directory segments and the final filename.

**File**: `Cloude/Cloude/UI/FileViewerBreadcrumb.swift`
