# Refactor Tier 1: Quick Cleanup

## Status: Active

## Scope
Low-risk, immediate cleanup tasks that reduce noise and improve organization.

## Tasks

### 1. Delete commented-out code
- `ChatView+ToolPill.swift` lines 16-20 (truncatedSummary), lines 63-72 (result summary display)
- `ToolDetailSheet.swift` lines 193-203 (tool result summaries)
- Feature was intentionally removed in Build 43

### 2. Move parsers out of UI/
- `YAMLParser.swift` → `Utilities/`
- `BashCommandParser.swift` → `Utilities/`
- Pure parsing logic doesn't belong in UI layer

### 3. Extract RelativeDateTimeFormatter helper
- 4 identical instances across ConversationStore.swift and HeartbeatStore.swift
- Extract to `DateFormatters.relativeTime(_:)` static helper

### 4. Remove debug print() statements
- ~15 instances across ConnectionManager+API, HeartbeatStore, AudioRecorder, LiveActivityManager
- Delete outright (not replacing with os.Logger — keep it simple)
