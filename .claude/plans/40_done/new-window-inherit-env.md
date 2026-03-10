# New Window Should Inherit Environment

## Problem
When tapping the plus icon to create a new window, the new conversation inherits the **working directory** from the active window but NOT the **environmentId**. This means the new window isn't linked to the correct Mac agent until the user sends a message.

## Affected Call Sites

1. **`MainChatView+Utilities.swift:16`** - `addWindowWithNewChat()` (plus button)
2. **`MainChatView+Windows.swift:27`** - `onNewConversation` in empty state

Both call `conversationStore.newConversation(workingDirectory: workingDir)` without passing `environmentId`.

## Already Correct
- **`MainChatView.swift:199`** - "New Chat" from window edit sheet already passes `environmentId: environmentStore.activeEnvironmentId`

## Fix
Add a helper to get the active environment ID (from the current window's conversation, falling back to `environmentStore.activeEnvironmentId`) and pass it to both call sites.

### Changes

**`MainChatView+Utilities.swift`**:
- Add `activeWindowEnvironmentId() -> UUID?` that reads the active window's conversation's `environmentId`, falling back to `environmentStore.activeEnvironmentId`
- Update `addWindowWithNewChat()` to pass `environmentId`

**`MainChatView+Windows.swift`**:
- Update `onNewConversation` to pass `environmentId`

## Files
- `Cloude/Cloude/UI/MainChatView+Utilities.swift`
- `Cloude/Cloude/UI/MainChatView+Windows.swift`
