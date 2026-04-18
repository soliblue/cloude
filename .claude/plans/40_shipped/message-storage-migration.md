# Message Storage Migration {externaldrive}
<!-- priority: 10 -->
<!-- tags: streaming -->
<!-- build: 56 -->

> Migrated message storage from UserDefaults to file-backed JSONL per conversation.

Move message storage from UserDefaults to file-backed JSONL per conversation. Keep lightweight summary cache for quick lists. Migration from UserDefaults on first launch. Add message count/size caps with graceful pruning.

**Files:** `ProjectStore.swift`, `ProjectStore+Conversation.swift`
