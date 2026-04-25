# Chat scroll + typing FPS perf investigation

**Blocked on**: `debug-log-upload-infra.md`. All verification relies on pulling the app perf log off-device via the new upload button.

## Goal

Confirm (or disprove) the suspected causes of the two chat-perf issues tracked in `open-issues.md`, then fix them.

## Hypotheses to verify

1. **Scroll lag**: markdown parser runs on every body eval of every visible row. No cache.
2. **Scroll lag**: `groupedMessages` computed property allocates fresh arrays + `MessageGroup`s on every render.
3. **Scroll lag**: `.animation(value: messages.count)` / `lastAnchoredUserId` invalidates the whole LazyVStack.
4. **Typing FPS**: `ChatView` body re-evals on every keystroke because `ChatInputBar`'s draft state drives `barHeight` via `onGeometryChange`, which writes to `@State` on `ChatView`, which also owns `@Query messages`.
5. **Typing FPS**: `ChatViewMessageList` body re-evals on every keystroke due to sibling invalidation.

## Instrumentation plan

Add a single `ChatPerfCounters` aggregator in `clients/ios/src/Core/Debug/`. Counters bumped from:

- `ChatView.body` — `cv.body`
- `ChatViewMessageList.body` — `ml.body`
- `ChatViewMessageList.groupedMessages` getter — `ml.grouped`
- `ChatMarkdownParser.parse(_:)` — `md.parse` + `md.parseDup` (when the same text hash parses again within N seconds)
- `ChatInputBar.body` — `ib.body`
- `ChatView.onGeometryChange` action — `cv.geo`

Tick once per second via a `Task` or `Timer` and emit via `AppLogger.performanceInfo`:
`perf tick cv=N ml=N grouped=N md=N mdDup=N ib=N geo=N`

Counters reset each tick. Only emit a tick line when any counter > 0 so idle doesn't spam.

## Scenarios

Both run against a chat already populated via `mixed-markdown-multi-tool.txt`.

- **A. Idle scroll**: scroll up and down for ~5s without typing. Read rates.
  - Confirms hyp 1 if `md.parse` > visibleRows × scrollEvents.
  - Confirms hyp 2 if `grouped` ticks per body eval rather than per message change.
  - Confirms hyp 3 if `ml.body` fires on pure scroll.
- **B. Typing**: type 10 characters in the input bar. Read rates.
  - Confirms hyp 4 if `cv.body` > 10.
  - Confirms hyp 5 if `ml.body` > 0.

## Fixes (to land once verified)

- Cache markdown parse result per `(messageId, textHash)`; invalidate on text change only.
- Memoize `groupedMessages` (compute once per message-set change, not per body eval).
- Scope `.animation(value:)` to the bottom-anchor scroll only, not the whole stack.
- Split `ChatView` so the `@State barHeight` and `ChatInputBar` sit in a sibling subview that does not hold `@Query messages`.

## Done when

- Every hypothesis is either confirmed (with numbers) or rejected (with numbers).
- Confirmed causes have a fix merged.
- Re-run of both scenarios shows counters drop to the expected floor.
