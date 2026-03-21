# Widget Interactions Feedback {arrow.uturn.backward.circle}
<!-- priority: 6 -->
<!-- tags: widget, agent, relay, input -->

> Send widget interaction data back to Claude so it knows what the user did.

## Problem

All widgets are currently fire-and-forget. Claude sends a quiz, flashcard, or terminal widget, but never learns how the user interacted with it. Claude is blind to widget results.

## Solution: iOS-side buffer, append on send

1. User interacts with a widget (answers quiz, types in terminal, etc.)
2. iOS stores the event locally in a buffer: `widgetEvents[toolCallId] = data`
3. When user sends their next message, iOS appends all accumulated widget events to the message text
4. Clear the buffer after sending
5. Claude sees widget context as part of the user message

No WebSocket events, no agent-side buffer. Everything stays on iOS until the user sends a message.

## Message format

User types "continue" but the message sent to Claude becomes:

```
continue

[Widget interactions]
- Quiz "Capital of France?": answered "Paris" (correct)
- Terminal "npm init": exited 0, output: "package.json created"
- Flashcards "Spanish Vocab": flipped 8/10 cards
```

## Widget event data

Each widget stores its interaction result when the user acts:

| Widget | Event data |
|--------|-----------|
| Quiz | `{answer: "B", correct: true}` |
| Flashcards | `{cardsFlipped: 5, total: 10}` |
| Type answer | `{typed: "Paris", correct: true}` |
| Ordering | `{order: [...], correct: true}` |
| Fill in blank | `{answers: ["dog", "cat"], correct: [true, false]}` |
| Matching | `{pairs: 6, correct: 5}` |
| Categorization | `{correct: 8, total: 10}` |
| Error correction | `{found: 3, total: 4}` |
| Highlight select | `{selected: [...], correct: true}` |
| Word scramble | `{solved: true, attempts: 2}` |
| Sentence builder | `{solved: true}` |
| Terminal | `{output: "last 50 lines...", exitCode: 0}` |
| Interactive function | `{paramValues: {a: 3.5, b: 2.0}}` |

## Implementation

### iOS Side

**Widget event store** (new property on ConversationStore or similar):
- `var pendingWidgetEvents: [(toolCallId: String, widgetType: String, summary: String)] = []`
- Each widget view calls `store.addWidgetEvent(...)` when user interacts
- On message send, format events as text block, append to message, clear buffer

**Each `WidgetView+*.swift`:**
- Add a callback/closure or environment object to report interactions
- Call it when the user completes an action (answers, finishes, exits)

**Message sending (ConversationStore+Messaging or GlobalInputBar):**
- Before sending, check `pendingWidgetEvents`
- If non-empty, append formatted summary to message text
- Clear buffer after send

### Files to modify

| File | Change |
|------|--------|
| `Cloude/Models/ConversationStore.swift` (or new) | Widget event buffer |
| `Cloude/UI/GlobalInputBar.swift` or `ConversationStore+Messaging.swift` | Append events on send |
| Each `WidgetView+*.swift` | Report interaction events |

No agent-side changes needed. No new message types. No WebSocket protocol changes.

### Prerequisite for
- Terminal widget (Phase 2 of terminal-tab plan) - Claude needs to see terminal output
- Adaptive learning flows - Claude adjusts difficulty based on quiz/exercise results
