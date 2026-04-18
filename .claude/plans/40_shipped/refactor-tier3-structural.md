---
title: "Refactor Tier 3: Structural Improvements"
description: "Larger architectural refactors improving structure after Tier 1+2 stabilized."
created_at: 2026-02-07
tags: ["refactor"]
icon: building.columns
build: 43
---


# Refactor Tier 3: Structural Improvements {building.columns}
## Status: Active

## Scope
Larger refactors that improve architecture. Higher risk — do after Tier 1+2 are stable.

## Tasks

### 1. Break up handleMessage switch (305 lines)
- ConnectionManager+API.swift handleMessage has 40+ cases in one switch
- Split into category handler methods: output, file, git, heartbeat, team
- Keep switch for dispatch (compile-time exhaustiveness) — just move bodies to methods
- Per Codex: category handlers over protocol dispatch

### 2. Break up GlobalInputBar.body (239 lines)
- Extract recording overlay, suggestion list, gesture handling into computed properties or subviews
- Keep @State vars in parent, pass via bindings
- Careful not to fragment gesture logic

### 3. Consolidate tool input extraction
- ConnectionManager+API.extractToolDetail and ClaudeCodeRunner+Streaming.extractToolInputString
- Verify both do the same thing, then consolidate to one shared function
- Likely belongs in CloudeShared
