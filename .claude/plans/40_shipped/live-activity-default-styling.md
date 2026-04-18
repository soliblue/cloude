---
title: "Live Activity Default Styling"
description: "Removed custom accent and forced backgrounds from Live Activity, using system defaults."
created_at: 2026-02-08
tags: ["ui", "theme"]
icon: livephoto
build: 66
---


# Live Activity Default Styling {livephoto}
## Changes
- Removed `Color.cloudeAccent` custom color
- Removed `.activityBackgroundTint(.white)` from lock screen
- Icons use `.tint` (system accent) instead of custom orange
- Conversation name uses default label color
- State indicators use `.secondary` instead of hard green/orange
- Compact running state uses spinner instead of green pulsing bolt

## File
- `Cloude/CloudeLiveActivity/CloudeLiveActivity.swift`
