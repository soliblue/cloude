# Android Session Continuity {arrow.triangle.turn.up.right.diamond}
<!-- priority: 3 -->
<!-- tags: android, chat, bug -->

> Fix multi-turn conversations so Claude remembers previous messages in the same session.

## Root Cause

The Android `ChatViewModel.sendMessage()` always sends `sessionId = null, isNewSession = true`, ignoring the stored sessionId. This forces a fresh Claude process for every message.

### iOS behavior (working)
1. First message: `sessionId = nil, isNewSession = true` (no session yet)
2. Agent responds with `session_id` message -> iOS stores `conv.sessionId`
3. Second message: `sessionId = <stored>, isNewSession = false`
4. Agent CLI: `--resume <sessionId>` flag continues the session

Key iOS line (`MainChatView+Messaging+Send.swift:33`):
```swift
let isNewSession = conv.sessionId == nil && !isFork
```

### Android behavior (broken)
1. First message: `sessionId = null, isNewSession = true` (correct)
2. Agent responds with `session_id` -> Android stores it in `_conversation.value.copy(sessionId = message.id)` (correct)
3. Second message: **still sends `sessionId = null, isNewSession = true`** (BUG)

## Fix

### `ChatViewModel.kt` - `sendMessage()`

Change from hardcoded values:
```kotlin
sessionId = null,
isNewSession = true,
```

To use stored session state:
```kotlin
sessionId = conv.sessionId,
isNewSession = conv.sessionId == null,
```

That's it. The sessionId is already stored correctly in the Conversation; it just needs to be used.

## Verification

1. Send first message -> should get response (same as before)
2. Send second message -> should get response that references the first message context
3. Check Logcat: second message JSON should show `"sessionId":"<uuid>","isNewSession":false`
4. Check Mac agent log: should show `--resume <sessionId>` in the CLI command

## Files
- `android-v2/app/src/main/java/com/cloude/app/Services/ChatViewModel.kt` (2-line fix)
