---
title: "File Viewer Actions Spacing"
description: "Added padding and dividers to file viewer action icons in the preview header."
created_at: 2026-02-07
tags: ["ui", "file-preview"]
icon: arrow.left.and.right
build: 40
---


# File Viewer Actions Spacing {arrow.left.and.right}
Add horizontal padding and dividers to FileViewerActions icons (share, copy, code) in the file preview header.

## Changes
- Added `.padding(.horizontal, 12)` to push icons away from edges
- Added `Divider().frame(height: 20)` between each icon (matching WindowEditSheet toolbar style)
- Reduced HStack spacing from 16 to 12 to balance with dividers

## Files
- `Cloude/Cloude/UI/FileViewerBreadcrumb.swift`
