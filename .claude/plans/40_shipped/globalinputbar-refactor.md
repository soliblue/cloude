---
title: "GlobalInputBar Refactor"
description: "Merge duplicate handlers, extract drag gesture and magic numbers from GlobalInputBar."
created_at: 2026-02-07
tags: ["input", "refactor"]
icon: arrow.triangle.2.circlepath
build: 43
---


# GlobalInputBar Refactor {arrow.triangle.2.circlepath}
## Status: Active

## Tasks
1. Merge duplicate `onChange(of: inputText)` handlers (lines 228 and 261) into single handler
2. Extract DragGesture handler (lines 172-215) into a helper method
3. Extract magic numbers into named constants enum

## Files
- `Cloude/Cloude/UI/GlobalInputBar.swift`
- `Cloude/Cloude/UI/GlobalInputBar+Components.swift` (check for magic numbers)
