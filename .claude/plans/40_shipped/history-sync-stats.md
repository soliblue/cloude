# History Sync: Preserve Run Stats {clock.arrow.2.circlepath}
<!-- build: 103 -->
<!-- priority: 10 -->
<!-- tags: conversations, ui -->

> Show partial run stats (model, timestamp) in the footer even when cost/duration are missing after history sync.

## Problem
After refreshing a conversation from the iOS app (history sync), the run stats footer (model, duration, cost) disappears. The `AssistantMessageFooter` gates the entire stats row behind `if let durationMs, let costUsd` - so when either is nil, even the model and timestamp vanish.

## Fix
Make the footer show whatever data is available instead of all-or-nothing:
- Always show timestamp
- Show model if present (comes through history sync already)
- Show duration/cost only when available (these are only set during live streaming)

## Files
- `Cloude/Cloude/UI/MessageBubble+Footer.swift` - change the conditional to show partial stats

## Future (optional)
- Relay could compute `costUsd` from JSONL token usage and `durationMs` from timestamps
- Would require price-per-token mapping in `handlers-history.js`
