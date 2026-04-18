# Fix Tool Pill Active State {wrench.and.screwdriver}
<!-- build: 120 -->
<!-- priority: 5 -->
<!-- tags: tools, ui, reliability -->

> Tool pills no longer stay in shimmer/executing state after the stream moves past them.

## Problem
Tool pills (InlineToolPill) only transitioned from `.executing` to `.complete` when an explicit `.toolResult` message arrived. If the result was missing or delayed, the pill stayed in shimmer state even after subsequent text or tool calls proved it was done.

## Fix
Added `completeTopLevelExecutingTools()` on `ConversationOutput` that marks all top-level executing tools (no `parentToolId`) as complete. Called in:
- `handleOutput` — new text means previous tools are done
- `handleToolCall` — new top-level tool means previous top-level tools are done
- Subtools don't trigger this (their parent may still be running)

**Files:** `ConnectionManager+ConversationOutput.swift`, `EnvironmentConnection+Handlers.swift`
