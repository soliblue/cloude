# Refactor: Naming, Deduplication & File Size Cleanup {pencil.and.list.clipboard}
<!-- priority: 10 -->
<!-- tags: refactor -->

> Phase 2 refactor: renamed files to domain-accurate names, flattened folders, deduplicated utilities.

**Status**: 20_active
**Agent**: Cloude (Opus)

## Scope
Phase 2 of architecture refactor:
1. Rename `ChatView+*` files → domain-accurate names
2. Flatten Charts folder
3. Deduplicate clipboard, conversation lookup, formatTimestamp
4. Split oversized files (ConversationView+Components, ConnectionManager+MessageHandler, MessageBubble, ToolDetailSheet, SettingsView)
5. Update CLAUDE.md UI Component Map
