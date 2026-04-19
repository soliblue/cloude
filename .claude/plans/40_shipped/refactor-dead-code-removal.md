---
title: "Dead Code Removal"
description: "Removed unused methods and exposed internal properties to simplify the codebase."
created_at: 2026-02-06
tags: ["refactor"]
icon: trash
build: 36
---


# Dead Code Removal
## Changes
- Removed `GlobalInputBar.configureEffort(from:)` - unused method
- Removed `QuestionJSON.AnyCodable.~=` operator - unused pattern matching
- Changed `ToolCallLabel.iconNameForDetail` to expose `iconName` directly

## Test
- Effort level selection in send button menu still works
- Tool pills display correct icons in chat
- Tool detail sheet shows correct icons when tapping pills
