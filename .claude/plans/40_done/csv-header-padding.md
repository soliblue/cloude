# CSV Header Padding Fix {rectangle.arrowtriangle.2.inward}
<!-- priority: 10 -->
<!-- tags: ui, file-preview -->
<!-- build: 64 -->

> Removed extra vertical padding between breadcrumb header and CSV table content in file preview.

## What
Remove extra vertical padding between the breadcrumb header and CSV table content in the file preview.

## Changes
- `FilePathPreviewView+Content.swift`: Removed `.padding(.vertical)` from CSV rendered view
