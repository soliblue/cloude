# Data Storage and Search Plan

## Goals
- Make conversation storage scale without hitting UserDefaults limits.
- Enable fast search across projects and conversations.
- Support export and portability.

## Current Observations
- Projects, conversations, and messages are stored in UserDefaults.
- Messages can grow unbounded, which risks size limits and performance.
- Search and export are not available.

## Opportunities

### Storage Layer
- Move message storage to file-backed JSON or SQLite per project.
- Keep a lightweight index in UserDefaults for quick boot.
- Add a storage version and migration path.

### Search
- Build a local search index (simple SQLite FTS or custom token index).
- Allow filters by project, date, sender, and tool usage.

### Export
- Export conversation to Markdown or PDF.
- Include tool calls and run stats in export.

## Proposed Phases

### Phase 0 - Guardrails
1. Add message count and size caps with graceful pruning.
2. Add "Clear old messages" action per project.

### Phase 1 - File-Based Storage
1. Store messages per conversation as JSONL on disk.
2. Keep a lightweight summary cache for quick lists.
3. Migration from UserDefaults on first launch.

### Phase 2 - Search and Export
1. Add full-text search across stored JSONL or SQLite FTS.
2. Add export flow (share sheet).

## Notes / Dependencies
- Conversation state: `Cloude/Cloude/Models/ProjectStore.swift` and `ProjectStore+Conversation.swift`.
- UI list views: `Cloude/Cloude/UI/ProjectConversationsView.swift`.
- Export hooks: `Cloude/Cloude/UI/ChatView+MessageBubble.swift`.
