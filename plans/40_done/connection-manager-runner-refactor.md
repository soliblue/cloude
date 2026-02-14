# ConnectionManager + RunnerManager Refactor
<!-- priority: 10 -->
<!-- tags: refactor -->
<!-- build: 56 -->

## Status: Testing

## Tasks

### 1. Break up handleMessage switch (ConnectionManager+API.swift)
- The `handleMessage` function dispatches 30+ message types with inline logic
- Break into per-message-type handler methods
- Keep main switch as thin dispatcher

### 2. Replace tuple in RunnerManager.activeTeams with proper struct
- `activeTeams` uses `(teamName: String, teammates: [String: TeammateInfo], lastInboxState: [String: Int])`
- Create named struct `ActiveTeam`

### 3. Standardize ServerMessage conversationId parameter ordering
- Move `conversationId` to last parameter position in:
  - `renameConversation`
  - `setConversationSymbol`
  - `deleteConversation`
  - `switchConversation`
- Update all construction/pattern-matching sites across codebase
