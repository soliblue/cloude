---
title: "Refactor R2: Extract BashCommandParser.chainedCommands helper"
description: "Extracted shared chained command parsing logic into a reusable BashCommandParser helper."
created_at: 2026-02-07
tags: ["refactor", "tool-pill"]
icon: terminal
build: 43
---


# Refactor R2: Extract BashCommandParser.chainedCommands helper {terminal}
## Status: Active

## Problem
Same guard + isScript + splitChainedCommands + count > 1 pattern repeated in:
- `ChatView+ToolPill.swift`
- `ToolDetailSheet.swift`
- `ChatView+ToolCalls.swift`

## Fix
Add to BashCommandParser:
```swift
static func chainedCommands(for input: String) -> [String] {
    guard !isScript(input) else { return [] }
    let commands = splitChainedCommands(input)
    return commands.count > 1 ? commands : []
}
```
