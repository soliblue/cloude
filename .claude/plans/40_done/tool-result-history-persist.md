# Persist Tool Results Through History Reload

## What Changed
- `StoredToolCall` now carries `resultContent: String?`
- Mac agent `HistoryService` parses `tool_result` entries from user messages in JSONL
- Linux relay `handlers-history.js` mirrors the same parsing
- iOS maps `resultContent` through to `ToolCall.resultOutput` on history sync and missed response

## Also Resolved: Scroll Position Bugs
Multiple scroll-related issues in ConversationView that were previously tracked separately:
1. Scrolled past messages on chat switch
2. Scrolled past messages during active use
3. Scroll-to-bottom button missing on app restart
4. Scroll-to-bottom button doesn't work

Root cause was `bottomId` sentinel in LazyVStack not loading for offscreen views, causing `isBottomVisible`/`scrollTo` to silently fail. Resolved through prior scroll fixes (see `40_done/scroll-overshoot-fix.md`, `40_done/stop-autoscroll-on-touch.md`, etc.)

## Files
- `CloudeShared/Models/HistoryMessage.swift`
- `Cloude Agent/Services/HistoryService.swift`
- `Cloude/App/CloudeApp+EventHandling.swift`
- `Cloude/Services/EnvironmentConnection+Handlers.swift`
- `linux-relay/handlers-history.js`
- `Cloude/Cloude/UI/ConversationView+Components.swift` (scroll logic)
