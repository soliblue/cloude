---
title: "Observation Chain Optimization"
description: "Eliminate ConversationView double-subscription and reduce ConversationStore publish frequency during finalization."
created_at: 2026-03-31
tags: ["performance"]
icon: gauge.with.dots.needle.bottom.50percent
build: 122
---


# Observation Chain Optimization
## Changes

### 1. ConversationView observation removal
- Changed `@ObservedObject var connection: ConnectionManager` → `let connection`
- Changed `@ObservedObject var store: ConversationStore` → `let store`
- ConversationView now re-renders only from parent (MainChatView), not from its own observation
- Safe because parent already observes both objects and passes updated data down

### 2. Finalize mutation consolidation
- Combined `updateMessage` + cost update into single `mutate` call in `finalizeStreamingMessage`
- Combined `addMessage` + cost update into single `mutate` call for non-live path
- Eliminates one ConversationStore objectWillChange publish per stream completion

## Verify

Outcome: streaming, tool calls, and abort all work correctly with reduced shell view renders.

Test:
1. Open a conversation, send a long markdown prompt
2. Verify text streams smoothly and completes
3. Send a tool-call prompt (e.g., "Read the README")
4. Verify tool calls render and complete
5. Send another prompt and tap stop to abort
6. Verify conversation returns to idle cleanly
