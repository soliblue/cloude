# Effort Level Implementation Plan

## Summary
Add adaptive thinking effort level support (low/medium/high/max) per conversation, with UI controls in the input bar and conversation settings.

## Approach: Option A - Prepend `/effort` to prompt
When effort differs from default (`high`), prepend `/effort <level>\n\n` to the prompt text sent to the CLI. The CLI processes slash commands even in `-p` mode.

## Changes by File

### 1. CloudeShared/Models/SharedTypes.swift
Add `EffortLevel` enum:
- Cases: `low`, `medium`, `high`, `max`
- Properties: `displayName` (String), `sfSymbol` (String), `next` (cycles to next level)
- Static `defaultLevel` = `.high`

### 2. Conversation.swift
- Add `var effortLevel: EffortLevel?` (nil = default high)
- Update `init()` - no change needed (nil default)
- Update `init(from decoder:)` - `decodeIfPresent`
- Update `CodingKeys` - add `effortLevel`
- Add computed `var effectiveEffort: EffortLevel { effortLevel ?? .high }`

### 3. ConversationStore+Operations.swift
- Add `setEffortLevel(_ conversation: Conversation, level: EffortLevel?)` following existing setter pattern

### 4. ClientMessage.swift
- Add `effortLevel: String?` to `.chat` case (String not enum, to keep agent-side decoding simple)
- Add `effortLevel` to `CodingKeys`
- Update `init(from decoder:)` and `encode(to:)` for `.chat`

### 5. ConnectionManager+API.swift
- Add `effortLevel: EffortLevel? = nil` param to `sendChat()`
- Pass `effortLevel?.rawValue` in the `.chat` message

### 6. Cloude_AgentApp.swift
- Extract `effortLevel` from `.chat` message
- Pass to `runnerManager.run()`

### 7. RunnerManager.swift
- Add `effortLevel: String? = nil` param to `run()`
- Pass to `runner.run()`

### 8. ClaudeCodeRunner.swift
- Add `effortLevel: String? = nil` param to `run()`
- When effortLevel is non-nil and not "high", prepend `/effort <level>\n\n` to `finalPrompt`

### 9. GlobalInputBar.swift
- Add `effortLevel: Binding<EffortLevel>` parameter
- Add brain icon button to the left of the photo picker
- Tapping cycles: low -> medium -> high -> max -> low
- Icon changes per level: `brain` with different visual treatment

### 10. MainChatView.swift
- Track effort level from current conversation
- Pass effort binding to GlobalInputBar
- Pass effort level to `sendChat()` in `sendConversationMessage()`
- Save effort changes to ConversationStore

### 11. WindowEditForm.swift
- Add effort level picker section (Picker with segmented style or menu)
- Update conversation's effort level on change

### 12. ConversationView.swift + ConversationView+Components.swift
- Pass effort level through `sendChat()` calls for queued message replay

### 13. HeartbeatChatView.swift / HeartbeatSheet.swift
- No changes needed (heartbeat uses default effort)

## UI Design

### Input Bar Brain Icon
- Position: left of photo picker button
- Appearance: `brain` SF Symbol
- Color varies by level:
  - low: `.secondary` (dimmed)
  - medium: `.orange`
  - high: `.accentColor` (blue, default)
  - max: `.purple`
- Tap to cycle through levels
- Small text label below or badge showing level name

### WindowEditForm Picker
- Segmented Picker or Menu with all 4 levels
- Each level shows name
- Placed after the name/symbol row, before folder picker

## Order of Implementation
1. SharedTypes.swift (enum)
2. Conversation.swift + ConversationStore+Operations.swift (storage)
3. ClientMessage.swift (protocol)
4. ConnectionManager+API.swift (iOS sending)
5. Cloude_AgentApp.swift -> RunnerManager.swift -> ClaudeCodeRunner.swift (agent receiving + CLI)
6. GlobalInputBar.swift (input bar UI)
7. MainChatView.swift (wiring)
8. WindowEditForm.swift (settings UI)
9. ConversationView.swift (queued message replay)
