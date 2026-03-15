# Refactor: March 2026 Cleanup

## HIGH Priority
- [x] ProcessMonitor: Extract shared `findProcesses(matching:excludingSelf:)` to deduplicate 95% identical code
- [x] ClaudeCodeRunner+Streaming: Split `processStreamLines` into typed handlers
- [x] CloudeApp: Extract `handleConnectionEvent` to `CloudeApp+EventHandling.swift`
- [x] RunnerManager: Extract team polling to `RunnerManager+TeamPolling.swift`

## MEDIUM Priority
- [x] Dead state: Remove unused `lastUserMessageCount` from ConversationView+Components
- [x] GlobalInputBar+ActionButton: Extract duplicated menu into `inputActionsMenuContent`
- [x] MessageBubble: Extract copy+toast pattern into helper
- [ ] RunnerManager: Group 12 closure callbacks into struct (deferred - touches too many call sites)
- [x] ClientMessage: Split encoding to `ClientMessage+Encoding.swift`

## File Splits
- [x] MessageBubble.swift: Extract types to `MessageBubble+TextSelection.swift`
- [x] TerminalView.swift: Extract bridge to `TerminalView+Bridge.swift`
- [x] Cloude_AgentApp+Handlers: Split into `+FileHandlers.swift` and `+TerminalHandlers.swift`
- [x] UsageStatsSheet.swift: Extract charts to `UsageStatsSheet+Charts.swift`
- [x] MainChatView.swift: Extract sheets to `MainChatView+Sheets.swift`
- [ ] GlobalInputBar.swift: Already well-split (recording, action button, components all separate) - skipped
