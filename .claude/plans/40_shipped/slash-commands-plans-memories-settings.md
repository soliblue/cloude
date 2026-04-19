---
title: "Slash Commands for Plans, Memories, Settings"
description: "Added /plans, /memories, and /settings as built-in slash commands that open their respective sheets."
created_at: 2026-03-03
tags: ["ui", "settings", "plans", "memory"]
icon: slash.circle
build: 82
---


# Slash Commands for Plans, Memories, Settings
Added `/plans`, `/memories`, and `/settings` as built-in slash commands:
- `/plans` opens the plans sheet (removed clipboard button from toolbar)
- `/memories` opens the memories sheet (brain button still in toolbar)
- `/settings` opens the settings sheet (accessible via status logo tap too)

All three are also accessible from the Settings page (Memories, Plans buttons alongside existing Usage Statistics button).

## Architecture
- All sheet state lives on CloudeApp (app-level, not chat-level)
- Slash commands use closures to bubble up to CloudeApp
- Settings page dismisses first, then opens the sheet after a short delay
- `openMemories()` and `openPlans()` helper functions deduplicate the loading logic
