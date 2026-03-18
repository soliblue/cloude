# Reliable Scroll-to-Bottom

Scroll-to-bottom works ~80% of the time. Three separate issues share the same root: manual scroll tracking with `ScrollViewReader`, invisible anchors, gesture conflicts, and excessive view invalidation during streaming.

## Problems

### 1. Unreliable scroll-to-bottom
`ScrollViewReader` + `scrollTo()` with an invisible `Color.clear` anchor. Sometimes fails to scroll or track bottom visibility correctly.

### 2. Scroll lag during streaming
Scrolling back down mid-stream feels laggy. Content size changes every frame (CADisplayLink text drain at 60Hz) while user is dragging, causing layout thrashing. Tried `.equatable()` on `MessageBubble` and throttling `objectWillChange` -- neither helped.

### 3. Scroll performance during streaming
`onChange(of: currentOutput)` fires on every token. `DragGesture` on `ScrollView` may conflict with native gesture recognition. `isBottomVisible` tracking via `onAppear`/`onDisappear` on bottom anchor may cause extra layout passes.

## Goals
- 100% reliable scroll-to-bottom
- Smooth scrolling during streaming
- Simpler code using native iOS 18+ APIs
- Remove invisible anchor hack

## Execution Order (informed by Codex review)

The scroll API change alone won't fix jank. The real culprit is `parent.objectWillChange.send()` firing at 60Hz on every token, invalidating the entire `ConnectionManager` observer tree every frame. Fix the disease before treating symptoms.

### Phase 1: Isolate streaming invalidation [DONE - stashed, awaiting metrics]
**What we did:**
1. Changed `ConversationOutput.text` didSet to only cascade `parent?.objectWillChange.send()` on empty/non-empty transitions (~2x per response instead of 60Hz)
2. Created `StreamingContentObserver` view that observes `ConversationOutput` directly via `@ObservedObject`
3. Passed `conversationOutput` through `ChatMessageList` to the observer
4. Net effect: during streaming, only the streaming bubble re-renders per token. The entire ConversationView/ChatMessageList/LazyVStack/all MessageBubbles no longer re-evaluate at 60Hz.

**What we expect:**
- Scrolling during streaming should feel dramatically smoother because the LazyVStack with all historical messages is no longer re-evaluated on every token
- The streaming bubble itself still updates at 60Hz (unchanged) since it observes ConversationOutput directly
- No functional regressions: .defaultScrollAnchor(.bottom) still handles auto-scroll, all boolean checks (isEmpty) still work via the transition cascade

**How to measure:** Deploy the debug overlay first (see Cloude/.claude/plans/10_next/debug-overlay.md), then compare FPS during scroll+streaming before and after unstashing Phase 1. Key metrics: FPS during scroll while streaming, view body evaluation counts, objectWillChange fire rate.

### Phase 2: Throttle UI commits during drag
- Keep buffering tokens at full speed
- Commit UI text updates at ~15-30Hz while user is actively dragging
- Flush immediately when drag ends
- Use `onScrollPhaseChange` (iOS 18) to detect drag state natively instead of custom `DragGesture`

### Phase 3: Migrate to ScrollPosition API (iOS 18+)
- Replace `ScrollViewReader` with `.scrollPosition($position)` binding
- `ScrollPosition.scrollTo(edge: .bottom)` for programmatic scroll (button tap, new user message)
- Use `onScrollGeometryChange` / `onScrollPhaseChange` for bottom-visibility detection (ScrollPosition alone isn't reliable for this)
- Remove `bottomId`, `scrollProxy`, `isInitialLoad` state
- Keep `.defaultScrollAnchor(.bottom)` for streaming auto-scroll (works alongside `.scrollPosition`)
- Keep `.highPriorityGesture` on button (scroll view gesture greediness is unavoidable)
- Note: the API migration itself may fix edge cases we can't explain, since Apple's internal scroll state machine has information our manual tracking doesn't (isPositionedByUser, native phase detection)

### Phase 4: Only if still needed
- Detach streaming bubble from ScrollView as fixed overlay (adds complexity + a11y edge cases, defer unless profiling proves necessary)

## Codex Review

### Findings
1. ScrollPosition(edge:) is iOS 18+, not iOS 17. Our deployment target is 26.0+ so not a blocker, but plan was mislabeled.
2. Switching scroll APIs alone won't fix jank. parent.objectWillChange.send() at 60Hz invalidates the entire view tree during drag.
3. Streaming markdown reparses are heavy. StreamingMarkdownView rebuilds content tree on every text change, competing with scroll layout on main thread.
4. ScrollPosition alone can't detect "at bottom." Need geometry/phase-based logic for bottom-visibility.
5. TapGesture marking userHasScrolled on any tap can suppress auto-scroll unexpectedly.

### Our Take
Codex nailed it. The phased approach above reflects their key insight: invalidation reduction first, API migration second. Phase 1 is the highest-impact change. Phase 3 is still worth doing for code simplicity but won't fix perf on its own.

## Files
- `Cloude/Cloude/UI/ConversationView+Components.swift` -- scroll handling, LazyVStack, StreamingContentObserver
- `Cloude/Cloude/Services/ConnectionManager+ConversationOutput.swift` -- CADisplayLink drain, objectWillChange cascading
- `Cloude/Cloude/UI/ConversationView.swift` -- passes conversationOutput to ChatMessageList
- `Cloude/Cloude/UI/MainChatView+HeartbeatChat.swift` -- passes conversationOutput for heartbeat
- `Cloude/Cloude/UI/MessageBubble.swift` -- bubble rendering
- `Cloude/Cloude/UI/StreamingMarkdownView.swift` -- markdown parsing per update
