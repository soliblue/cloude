---
title: "Combined Environment + Folder Selector"
description: "Grouped environment and folder pickers into a single card with auto-open folder picker on env change and disabled state when disconnected."
created_at: 2026-03-13
tags: ["ui", "env"]
icon: rectangle.on.rectangle
build: 86
---


# Combined Environment + Folder Selector
- Environment and folder pickers grouped into a single rounded card
- Environment row on top, folder row below, separated by a divider
- Both rows stretch full width with chevrons aligned right
- Single `oceanSecondary` background communicates they're related
- Changing environment auto-opens the folder picker sheet (only if env is connected)
- Folder picker disabled (dimmed) when environment connection is not live
- Window tabs (files, git, terminal) disabled when environment is disconnected
