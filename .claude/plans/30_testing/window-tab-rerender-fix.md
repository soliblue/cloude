# Window Tab Re-render Fix {bolt}
<!-- build: 115 -->
<!-- priority: 4 -->
<!-- tags: performance, swiftui -->

> Reduce unnecessary re-renders in window tab bar and page indicator during streaming.

## What Changed
- Extracted `WindowTabBar` as standalone struct (was extension method on MainChatView). Takes only primitive values (WindowType, Bool, closure) so SwiftUI skips re-renders when values unchanged.
- Removed `toolCalls` and `runStats` propagation from ConversationOutput to ConnectionManager. These fired on every tool call (~50+ per turn) but only ObservedMessageBubble needs them (observes ConversationOutput directly).
- `isRunning`, `isCompacting`, `text`, `newSessionId`, `skipped` still propagate (needed by input bar, page indicator).

## What to Test
- Run a conversation and check debug overlay for WindowTabBar render frequency (should be much less than before)
- Verify streaming still works (text appears, tool pills animate, stop button shows)
- Verify tab switching (chat/terminal/files/git) still works
- Verify page indicator still pulses for streaming windows
- Verify connection/disconnect still disables non-chat tabs
