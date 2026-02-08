# Message Storage Migration
<!-- priority: 10 -->
<!-- tags: messages -->
<!-- build: 56 -->

Move message storage from UserDefaults to file-backed JSONL per conversation. Keep lightweight summary cache for quick lists. Migration from UserDefaults on first launch. Add message count/size caps with graceful pruning.

**Files:** `ProjectStore.swift`, `ProjectStore+Conversation.swift`
