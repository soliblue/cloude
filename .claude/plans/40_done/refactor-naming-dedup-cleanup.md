# Refactor: Naming, Deduplication & File Size Cleanup

**Status**: 20_active
**Agent**: Cloude (Opus)

## Scope
Phase 2 of architecture refactor:
1. Rename `ChatView+*` files → domain-accurate names
2. Flatten Charts folder
3. Deduplicate clipboard, conversation lookup, formatTimestamp
4. Split oversized files (ConversationView+Components, ConnectionManager+MessageHandler, MessageBubble, ToolDetailSheet, SettingsView)
5. Update CLAUDE.md UI Component Map
