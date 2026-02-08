# CSV Table — Remove Unnecessary Horizontal Padding
<!-- build: 57 -->

<!-- status: testing -->
<!-- priority: low -->
<!-- tags: ui, files -->

## Problem
CSV files rendered in the file viewer had unnecessary white padding on the left and right sides. The `scrollingContent` wrapper added 16pt padding on all sides, but CSVTableView already handles its own horizontal cell padding internally.

## Fix
Removed the `scrollingContent` wrapper for CSV and applied only vertical padding + background directly. The table's own cell padding (8pt horizontal per cell) is sufficient.

**File**: `FilePathPreviewView+Content.swift`
