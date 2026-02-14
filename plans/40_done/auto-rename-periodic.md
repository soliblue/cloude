# Auto-Rename Every N Messages
<!-- priority: 10 -->
<!-- build: 56 -->

## Summary
Periodically re-run the background Sonnet naming call as conversations progress. The first message triggers naming, then every ~5 assistant messages, fire another name suggestion to keep the header accurate as topics shift.

## Why
Conversations drift. A chat that starts as "Git Push" might become about database schemas 10 messages later. Currently the name only updates if the agent manually calls `cloude rename`, which is unreliable and wastes agent turns.

## Implementation

### iOS Side (MainChatView+Messaging)
- Track message count per conversation (or use `conv.messages.count`)
- After adding an assistant message, check if `messages.count % 5 == 0` (every 5th message)
- If so, fire `connection.requestNameSuggestion(text: lastFewMessages, conversationId:)`
- Send the last 3-4 messages as context (not just the first message like initial naming)

### Mac Agent Side
- Already handled — `suggestName` works, just needs richer context
- Update the prompt to accept recent messages, not just a single message

### Protocol Change
- Extend `suggestName` to accept `context: [String]` (array of recent messages) instead of just `text`
- Or keep it simple: concatenate last 3 messages into the `text` field

## UX
- Name updates smoothly via existing crossfade (same `onRenameConversation` path)
- No flicker — only update if the name actually changed
- Agent can still override with `cloude rename` at any point
