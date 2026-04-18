---
title: "Toolbar & Window Header Cleanup"
description: "Simplify the toolbar and window header by removing clutter and fixing the nav pill crash."
created_at: 2026-03-23
tags: ["ui", "cleanup", "windows"]
icon: paintbrush
build: 103
---


# Toolbar & Window Header Cleanup {paintbrush}
## Background

Originally planned as a bigger rehaul (see original plan below) with context menus on bottom bar, right-aligned nav pill, removing exportCopied state, etc. Tried that on a `ui-rehaul` branch but it didn't work out well. Instead took an incremental approach on main, making small targeted changes and deploying each one to test on device. The result is cleaner and simpler than the original plan.

## Changes
- Removed `environmentIndicators` (env connect/disconnect icons) from toolbar center
- Removed power button from toolbar top right
- Removed export, fork, and refresh buttons from window header
- Moved dismiss (xmark) button from window header to toolbar top right
- Nav pill now 2 lines: conversation name on top, env icon + folder + cost on second line
- Window header tabs (chat, folders, git, terminal) now fill full width with dividers
- Added `contentShape(Rectangle())` so entire tab area is tappable
- Fixed nav pill crash: `editingWindow!` force-unwrap replaced with sheet-passed window parameter

## What Was NOT Done (from original plan)
- Bottom bar context menu (Refresh, Export, Fork, Edit) - kept long press for WindowEditSheet
- Removing `exportCopied` state - still exists but unused from header
- Deleting `connectAllConfiguredEnvironments()` - still exists
- Right-aligning the nav pill - kept it centered

## Files
- `CloudeApp+MainContent.swift` - toolbar items (removed power, added xmark, swapped environmentIndicators for navTitlePill)
- `CloudeApp+Toolbar.swift` - removed environmentIndicators, made navTitlePill 2-line VStack with env icon
- `MainChatView+WindowHeader.swift` - stripped to just tab buttons with dividers
- `MainChatView+Lifecycle.swift` - editWindowSheet now takes window parameter
- `MainChatView.swift` - passes sheet item to editWindowSheet

## Status
Done. Deployed directly to iPhone and tested.
