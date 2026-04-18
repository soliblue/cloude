# Breadcrumb Overflow - Collapse to Last 2 {rectangle.compress.vertical}
<!-- priority: 10 -->
<!-- tags: ui, file-preview -->
<!-- build: 57 -->

> Collapsed breadcrumb to show only root + ellipsis + last 2 segments for paths with 4+ segments.

Show only root + `…` + last 2 parent components instead of 3 when path has 4+ segments. Keeps breadcrumb from overflowing screen width.

**File**: `Cloude/Cloude/UI/FileViewerBreadcrumb.swift`

**How to test**: Open a deeply nested file like `Cloude/Cloude Agent/Services/AutocompleteService.swift` — breadcrumb should fit on screen without horizontal overflow.
