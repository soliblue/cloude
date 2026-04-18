---
title: "Edit Tool Diff View"
description: "Added inline diff view to Edit tool detail sheet showing old_string/new_string changes."
created_at: 2026-03-15
tags: ["ui", "tool-pill"]
icon: arrow.left.arrow.right
build: 86
---


# Edit Tool Diff View {arrow.left.arrow.right}
## Problem
When tapping an Edit tool pill, the detail sheet only shows the file path and a "updated successfully" confirmation. The CLI has `old_string` and `new_string` in the tool_use input, but `ToolInputExtractor` discards them, keeping only `file_path`.

## Solution
Thread `old_string`/`new_string` through the full pipeline and show an inline diff in the tool detail sheet using the existing `DiffTextView` components.

## Data Flow
1. CLI streams `tool_use` with `{file_path, old_string, new_string, replace_all}`
2. `ToolInputExtractor` extracts into new `EditInfo` struct (lives in CloudeShared)
3. `StoredToolCall` and `ToolCall` carry optional `editInfo`
4. `ServerMessage.toolCall` includes `editInfo`
5. On refresh, `HistoryService` extracts `editInfo` from jsonl
6. `ToolDetailSheet` renders diff using existing `DiffScrollView`

## Changes
- `CloudeShared/EditInfo.swift` - new struct
- `CloudeShared/ToolInputExtractor.swift` - new `extractEditInfo` method
- `CloudeShared/Models/HistoryMessage.swift` - add editInfo to StoredToolCall
- `CloudeShared/Messages/ServerMessage.swift` - add editInfo to toolCall case
- `Cloude Agent/Services/ClaudeCodeRunner+Streaming.swift` - extract and pass editInfo
- `Cloude Agent/Services/RunnerManager.swift` - thread editInfo through
- `Cloude Agent/App/Cloude_AgentApp.swift` - broadcast editInfo
- `Cloude Agent/Services/HistoryService.swift` - extract editInfo from jsonl
- `Cloude/Models/Conversation.swift` - add editInfo to ToolCall
- `Cloude/Services/EnvironmentConnection+Handlers.swift` - pass editInfo
- `Cloude/UI/ToolDetailSheet.swift` - show diff section for Edit
- `Cloude/UI/ToolDetailSheet+Content.swift` - editDiffSection using DiffScrollView
