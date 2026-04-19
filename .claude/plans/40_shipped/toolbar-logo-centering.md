---
title: "Center Toolbar Logo"
description: "Logo in the navigation toolbar was visually off-center due to extra padding on the leading toolbar items."
created_at: 2026-02-08
tags: ["ui", "header"]
icon: person.crop.circle
build: 64
---


# Center Toolbar Logo
## Change
- Removed `.padding(.horizontal, 14)` from the leading toolbar HStack in `CloudeApp.swift`
- The `.principal` placement now centers the `ConnectionStatusLogo` naturally between leading and trailing items

## Files
- `Cloude/Cloude/App/CloudeApp.swift`
