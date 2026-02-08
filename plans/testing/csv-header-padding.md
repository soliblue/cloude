# CSV Header Padding Fix

**Status:** testing
**Tags:** ui, files

## What
Remove extra vertical padding between the breadcrumb header and CSV table content in the file preview.

## Changes
- `FilePathPreviewView+Content.swift`: Removed `.padding(.vertical)` from CSV rendered view
