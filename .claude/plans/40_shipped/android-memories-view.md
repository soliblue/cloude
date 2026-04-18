---
title: "Android Memories View"
description: "View and browse CLAUDE.local.md memory sections in a sheet."
created_at: 2026-04-02
tags: ["android", "memories"]
build: 125
icon: brain
---
# Android Memories View {brain}


## Desired Outcome
Display memory sections parsed from CLAUDE.local.md. Section cards with title, icon, and expandable content. Refresh from agent on demand.

## iOS Reference Architecture

### Data flow
1. Server sends `ServerMessage.Memories` containing raw markdown text of CLAUDE.local.md
2. `MemoryParser.swift` parses markdown into hierarchical `MemoryDocument`:
   - Splits by `## Section {sf.symbol}` headers into `ParsedMemorySection`
   - Each section has subsections from `### Subsection {sf.symbol}` headers
   - Individual bullet points become `MemoryItem` with content and optional timestamp
3. `MemoryDocument` contains source (local vs project) and list of sections

### UI structure
- `CloudeApp+MemoriesSheet.swift` - modal sheet with two tabs: Personal (CLAUDE.local.md) and Project (CLAUDE.md)
- `CloudeApp+MemoryCards.swift` - section cards with SF Symbol icon from header, title, expand/collapse, subsection list, individual memory items

### Android implementation notes
- Parse `## Section {sf.symbol}` headers, map SF Symbol names to Material Icons
- Use `ModalBottomSheet` with `LazyColumn` for sections
- `ServerMessage.Memories` already handled in message parsing (just needs UI)
- Expandable cards with `AnimatedVisibility` for section content

**Files (iOS reference):** CloudeApp+MemoriesSheet.swift, CloudeApp+MemoryCards.swift, MemoryParser.swift, MemoryDocument.swift

## Implementation Status

### Done
- Android UI: MemoriesSheet.kt with ModalBottomSheet, expandable section cards, SF Symbol to emoji mapping, MemoryParser, MemoryModels
- Brain button in toolbar triggers requestMemories()
- ClientMessage.GetMemories now sends workingDirectory (matching GetPlans pattern)
- Swift ClientMessage.getMemories updated to accept workingDirectory: String?
- Mac agent handler passes workingDirectory to MemoryService.projectDirectory

### Blocked
- Sheet opens but displays empty sections. The Mac agent's MemoryService.projectRoot (uses #file to walk up and find CLAUDE.md) may not resolve to the correct directory at runtime. Needs debugging with Mac agent logs to verify what path parseMemories() reads from and whether CLAUDE.local.md is found.
- The workingDirectory sent by Android is the agent's default working directory, but the Mac agent's MemoryService was designed to use a compiled-in path. Need to verify the interaction between projectDirectory (set from workingDirectory) and projectRoot (fallback).
- Alternatively, the Mac agent may need to be rebuilt and relaunched for the Swift changes to take effect.

### Files changed
- android/.../Models/MemoryModels.kt (new)
- android/.../Services/MemoryParser.kt (new)
- android/.../UI/memories/MemoriesSheet.kt (new)
- android/.../Services/ChatViewModel.kt (requestMemories, handleMessage)
- android/.../App/MainActivity.kt (brain button, sheet rendering)
- android/.../Models/ClientMessage.kt (GetMemories with workingDirectory)
- Cloude/CloudeShared/.../ClientMessage.swift (getMemories with workingDirectory)
- Cloude/CloudeShared/.../ClientMessage+Decoding.swift
- Cloude/CloudeShared/.../ClientMessage+Encoding.swift
- Cloude/Cloude Agent/App/AppDelegate+MessageHandling.swift
- Cloude/Cloude/App/CloudeApp+Actions.swift
