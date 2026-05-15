---
title: "iOS File Browsing Modal Sheet"
description: "Move files browsing from inline tab to modal sheet with proper file preview navigation."
created_at: 2026-05-14
tags: ["ui", "files"]
icon: folder
build: 156
---

# iOS File Browsing Modal Sheet

Refactored the files browsing experience to open as a modal sheet instead of being embedded as a tab. This improves navigation flow and separates concerns between the main chat view and file management.

## Key Changes

- **FileTreeSheet**: New wrapper component that presents the file tree as a modal with proper chrome
- **FilePreviewSheet navigation-aware**: Detects whether it's pushed within a NavigationStack or presented as a standalone sheet, positioning toolbar buttons accordingly:
  - Trailing edge when pushed (avoids collision with back chevron)
  - Leading edge when standalone sheet (avoids collision with dismiss button)
- **SessionViewContent simplification**: Removed conditional tab logic, always displays chat
- **WindowsView tab resolution**: Simplified to always center on chat view
- **FileTreeViewRow refactoring**: Extracted label rendering into `rowLabel` property for reuse

## Daemon Updates

- **showHidden query parameter**: Both macOS and Linux daemon file listing endpoints now support filtering hidden files via query parameter

## Tool Pill Improvements

- Agent tool output now renders as markdown instead of plain text
- Error states are highlighted in danger color
- Better structured display of tool execution results
