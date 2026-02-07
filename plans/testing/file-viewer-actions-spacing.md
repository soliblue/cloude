# File Viewer Actions Spacing

Add horizontal padding and dividers to FileViewerActions icons (share, copy, code) in the file preview header.

## Changes
- Added `.padding(.horizontal, 12)` to push icons away from edges
- Added `Divider().frame(height: 20)` between each icon (matching WindowEditSheet toolbar style)
- Reduced HStack spacing from 16 to 12 to balance with dividers

## Files
- `Cloude/Cloude/UI/FileViewerBreadcrumb.swift`
