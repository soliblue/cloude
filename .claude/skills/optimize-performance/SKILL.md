---
name: optimize-performance
description: "Measure, compare, and eliminate unnecessary re-renders and wasted work across the app using before/after simulator testing."
user-invocable: true
metadata:
  icon: gauge.with.dots.needle.bottom.50percent
  aliases: [perf, optimize, rerender, re-render]
argument-hint: "[view or area to optimize]"
---

# Optimize Performance

Eliminate unnecessary re-renders and wasted work. Every optimization must be measured with before/after data on the simulator.

## Principles

- Measure first, optimize second. No guessing.
- Before/after comparison is mandatory. No "should be faster."
- Read completed performance plans before proposing changes.
- Consult codex on your planned change before implementing.
- The goal is zero unnecessary re-renders, not just fewer.

## Prior Art

Read these done plans before starting. They document past performance decisions and patterns:

```bash
cat .claude/plans/40_done/window-tab-rerender-fix.md
cat .claude/plans/40_done/streaming-static-transition-investigation.md
cat .claude/plans/40_done/unified-streaming.md
cat .claude/plans/40_done/streaming-text-ux.md
cat .claude/plans/40_done/fix-streaming-rerender.md
```

Search for more with:

```bash
grep -l "tags:.*performance\|re-render\|owcPerSec" .claude/plans/40_done/*.md
```

## Debug Metrics

The app has built-in render logging gated by `debugOverlayEnabled`. Enable it:

```bash
xcrun simctl spawn booted defaults write soli.Cloude debugOverlayEnabled -bool true
```

### Existing render log sources

| Source | View | File |
|--------|------|------|
| `LiveBubble` | ObservedMessageBubble | `MessageBubble+LiveWrapper.swift` |
| `ConvView` | ConversationView | `ConversationView.swift` |
| `MainChat` | MainChatView | `MainChatView.swift` |
| `WindowTabBar` | WindowTabBar | `MainChatView+WindowHeader.swift` |
| `PageIndicator` | PageIndicator | `MainChatView+PageIndicator.swift` |
| `InputBar` | GlobalInputBar | `GlobalInputBar.swift` |

### Adding render logs

Add `#if DEBUG` render logs to any view you're investigating:

```swift
#if DEBUG
let _ = DebugMetrics.log("ViewName", "render | key=\(value)")
#endif
```

Place it as the first line inside `var body: some View {`.

Logs write to both `NSLog` and `Documents/debug-metrics.log` in the simulator container.

### Performance samples

The app emits per-second FPS and objectWillChange rate to the app log:

```
debug sample fps=60 owcPerSec=0
```

Find these in `Documents/app-debug.log`.

## Workflow

### 1. Understand

Read the prior art plans. Understand why the current architecture looks the way it does. Many decisions have non-obvious reasons (e.g., `resetAfterLiveMessageHandoff` ordering, `wasInterrupted` flags, `seedForReconnect`).

### 2. Identify

Add render logs to the view(s) under investigation. Build and test on simulator.

```bash
.claude/skills/agentic-testing/start-local-simulator.sh
```

Enable debug overlay:

```bash
xcrun simctl spawn booted defaults write soli.Cloude debugOverlayEnabled -bool true
```

Terminate and relaunch:

```bash
xcrun simctl terminate booted soli.Cloude
sleep 1
xcrun simctl launch booted soli.Cloude
```

### 3. Measure baseline

Open a conversation, switch to haiku, trigger the flow being tested:

```bash
.claude/skills/agentic-testing/open-repo-conversation.sh
xcrun simctl openurl booted "cloude://conversation/model?value=haiku"
```

Clear the metrics log, trigger the flow, capture results:

```bash
CONTAINER=$(xcrun simctl get_app_container booted soli.Cloude data)
echo "" > "$CONTAINER/Documents/debug-metrics.log"

# trigger the flow (streaming, navigation, sheet open, etc.)
.claude/skills/agentic-testing/send-simulator-message.sh "your prompt"
sleep 30

# count renders per source
for source in LiveBubble ConvView MainChat WindowTabBar PageIndicator InputBar; do
    count=$(grep "\[$source\]" "$CONTAINER/Documents/debug-metrics.log" | wc -l)
    echo "$source: $count renders"
done

# check FPS
grep "debug sample" "$CONTAINER/Documents/app-debug.log" | tail -20
```

### 4. Plan the fix

Consult codex with your diff and the architectural context:

```bash
codex exec -s read-only -C "$(git rev-parse --show-toplevel)" "QUESTION WITH DIFF AND CONTEXT"
```

### 5. Implement and measure after

Apply the fix. Rebuild:

```bash
cd Cloude && xcodebuild -project Cloude.xcodeproj -scheme Cloude -configuration Debug -sdk iphonesimulator -destination 'id=DEVICE_ID' build
xcrun simctl terminate booted soli.Cloude
xcrun simctl install booted PATH_TO_APP
sleep 1
xcrun simctl launch booted soli.Cloude
```

Run the exact same test as baseline. Compare numbers.

### 6. Report

Present a before/after table:

```
| Metric | Before | After |
|--------|--------|-------|
| Total renders | X | Y |
| Wasted renders | X | Y |
| FPS | X | Y |
```

## Key Architecture Notes

### SwiftUI observation

- `@ObservedObject` subscribes to ALL `@Published` changes on the object. Every subscriber re-evaluates its body on every publish.
- `@State` changes only re-evaluate the owning view's body.
- `.onReceive(publisher)` fires the closure but does NOT re-evaluate the body unless `@State` changes inside it.
- `let` reference types do NOT create observation subscriptions. The view only re-evaluates when a parent triggers it.

### Streaming data flow

1. WebSocket chunks arrive → `ConversationOutput.appendText()` → `fullText` grows
2. `CADisplayLink` drain at 60Hz → `@Published var text` updates (300-1200 chars/sec)
3. `text` publishes → any `@ObservedObject` subscriber re-evaluates
4. `StreamingMarkdownView` incrementally appends via `frozenBlocks` + `tailBlocks`
5. On completion: `finalizeStreamingMessage` → `resetAfterLiveMessageHandoff` (clears `liveMessageId` first, then text on next tick)

### What propagates to ConnectionManager

Only state transitions propagate up (trigger MainChatView, InputBar, etc.):
- `isRunning` changes
- `isCompacting` changes
- `text` empty↔non-empty transition
- `newSessionId` changes
- `skipped` changes

These do NOT propagate (only ObservedMessageBubble sees them):
- `text` content updates (60Hz drain)
- `toolCalls` updates
- `runStats` updates

### Common anti-patterns

1. **@ObservedObject on shared state**: N views observing the same object = N re-renders per publish. Fix: use `let` + `.onReceive` with guarded `@State` updates.
2. **View type branching in ForEach**: `if condition { ViewA } else { ViewB }` causes view destruction/recreation when the branch changes. Fix: keep the same view type, vary props.
3. **Passing observable objects through view hierarchy**: Each level that stores an `@ObservedObject` creates another subscriber. Fix: pass as `let` and only observe at the leaf that needs updates.
4. **Over-broad store observation**: Observing `ConversationStore` means re-rendering on ANY conversation change. Consider whether the view actually needs the full store.

### 7. Document learnings

After each optimization run, append what you learned to the **Optimization Log** section at the bottom of this skill file. Each entry should include:
- What was optimized
- The root cause
- The fix pattern used
- Before/after numbers
- Any gotchas or surprises

This makes the skill smarter over time. Future runs start by reading these entries to avoid repeating mistakes and to reuse proven patterns.

## Optimization Log

### Streaming message re-renders (build 122)
- **What**: All message bubbles re-rendered ~60x/sec during streaming
- **Root cause**: `@ObservedObject var output: ConversationOutput` in `ObservedMessageBubble` subscribed every message to the 60Hz text drain
- **Fix**: `let output` + `@State` + `.onReceive` with guarded updates. Non-live closures check `isLive` and skip, so no `@State` change, so no body re-evaluation.
- **Numbers**: 9,233 → 1,036 total renders. ~8,900 → 16 wasted renders.
- **Gotcha**: `isLive` now relies on store mutations to trigger parent re-evaluation (implicit dependency). Works because `liveMessageId` always changes alongside a store mutation. Codex flagged this as medium risk but confirmed all current code paths are safe.
- **Gotcha**: The 16 remaining wasted renders are initial layout passes in the first ~2 seconds. Unavoidable SwiftUI behavior.

### Observation chain + FPS degradation (build 123)
- **What**: ConversationView double-subscribed to ConnectionManager/ConversationStore. FPS degraded from ~47 to 21 during long streams.
- **Root cause 1**: `@ObservedObject` on ConversationView duplicated observation already handled by parent (MainChatView). ConversationView re-rendered from both its own subscription AND the parent passing new values.
- **Root cause 2**: `StreamingMarkdownView` used a non-lazy `VStack` with `ForEach` over ALL blocks (frozen + tail). As blocks accumulated during streaming, layout cost grew linearly. Also, `stableSplitPoint` scanned all lines O(n) on every 60Hz update.
- **Root cause 3**: `finalizeStreamingMessage` called `mutate` twice (message update + cost update), causing two ConversationStore publishes per completion.
- **Fix 1**: Changed `@ObservedObject var connection/store` to `let` on ConversationView. Parent already observes and passes updated data.
- **Fix 2**: Extracted frozen blocks into `FrozenBlocksSection` conforming to `Equatable`. With `.equatable()`, SwiftUI skips body evaluation entirely when frozen blocks haven't changed. Made `stableSplitPoint` incremental (caches fence state + search offset, only scans new content).
- **Fix 3**: Combined message update + cost update into single `mutate` call in both finalization paths.
- **Numbers**: FPS during long stream: 47→21 (degrading) → 55-61 (stable). Shell renders per stream: reasonable (MainChat ~9, ConvView ~16 for 2 windows).
- **Gotcha**: `FrozenBlocksSection` equality compares block count + last block ID, not full content. Safe because frozen blocks only grow (append-only during streaming).
- **Gotcha**: Equatable only helps text-only streaming. With tool calls, all blocks go in tailBlocks (no freezing). Tool call path was already fast since responses are shorter.
- **Pattern**: When parent already observes a shared object, child views should use `let` (not `@ObservedObject`) to avoid double-subscription. Use `Equatable` views with `.equatable()` for sections that don't change between renders.

### Frozen split for tool calls + incremental parsing (build 124)
- **What**: Tool-call streaming responses (14K+ chars, 5+ tools) caused FPS to degrade from 60 to 20. WindowEditForm had 4 unnecessary @ObservedObject subscriptions.
- **Root cause**: When toolCalls was non-empty, StreamingMarkdownView disabled frozen/tail split entirely, putting ALL blocks in tailBlocks. With 14K chars, re-parsing everything at 60Hz was too expensive. Also, text-only frozen blocks were fully re-parsed on every split point move instead of appending the delta. Tail block prefix computation happened in body instead of during state update.
- **Fix 1**: Enabled frozen/tail split for tool-call responses. Tool call textPositions are adjusted relative to the tail region. Tools in frozen region are naturally skipped by parseWithToolCalls position checks.
- **Fix 2**: Incremental frozen block parsing: when frozen content grows (append-only), only the delta is parsed and appended to existing blocks.
- **Fix 3**: Moved `prefixed("tail-")` mapping from ForEach in body to updateIncremental(), avoiding array allocation per body evaluation.
- **Fix 4**: WindowEditForm 4 @ObservedObject to let (parent WindowEditSheet already observes).
- **Numbers**: Long text stream FPS: 47-20 (degrading) to 54-61 (stable). Tool call stream: 20-35 (degrading) to 60-61 (stable).
- **Gotcha**: Tool calls in frozen region are always complete by the time text streaming resumes after them, so stale tool state in frozen blocks is not a practical concern.
- **Pattern**: When content has positional metadata (tool calls), adjust positions when splitting into regions. Incremental append is safe when split points are at clean block boundaries (blank lines for markdown).

### Adaptive streaming throttle (build 125)
- **What**: LiveBubble rendered 1059 times per stream, causing FPS to degrade from 55 to 20 in the final seconds of long responses (8K+ chars).
- **Root cause**: Every CADisplayLink text publish (60Hz) triggered a @State change in ObservedMessageBubble, even when the tail section had grown large and each render was expensive.
- **Fix**: Adaptive throttle in `.onReceive(output.$text)`: when text exceeds 3000 chars, updates are limited to 20Hz (50ms minimum interval). Below 3000 chars, full 60Hz updates. Also removed dead `isComplete` property from StreamingMarkdownView and dead `textChanged` variable.
- **Numbers**: LiveBubble renders: 1059 → 726 (31% reduction). FPS during 12K char stream: 55-61 throughout (no degradation). Previously: 55 → 20.
- **Gotcha**: The throttle must still allow "shrinking" updates (text.count < liveText.count) to pass through immediately for abort/reset scenarios.
- **Pattern**: Adaptive throttle: use full update rate when cheap, reduce when expensive. The threshold (3000 chars) roughly corresponds to when tail blocks start accumulating enough to impact layout cost.

### Search sheet debounce (build 125)
- **What**: ConversationSearchSheet filtered through all message text on every keystroke.
- **Root cause**: `results` computed property did `conv.messages.contains { $0.text.lowercased().contains(query) }` for every conversation — O(n*m*k) per keystroke where n=conversations, m=messages, k=message length.
- **Fix**: Added 200ms debounce between `searchText` and `debouncedQuery`. Empty query clears immediately for instant "show all" behavior.
- **Pattern**: Debounce expensive computed properties that depend on user input. Use immediate clear for empty state to avoid perceived latency.

### Equatable PageIndicator (build 126)
- **What**: PageIndicator rendered 14 times per stream, same as MainChatView, despite its visible content rarely changing.
- **Root cause**: PageIndicator was an inline `@ViewBuilder func` on MainChatView, so it re-evaluated on every MainChatView body evaluation. It also did O(n) conversation lookups per window inside the render path.
- **Fix**: Extracted as a separate `PageIndicatorView` struct conforming to `Equatable`. Pre-computes display data (window names, streaming states) as `WindowItem` array. Custom `==` ignores closures, only compares visible data. Uses `.equatable()` modifier.
- **Numbers**: PageIndicator renders: 14 → 3 per stream.
- **Pattern**: For views with closures that need equatable optimization: conform to Equatable with custom `==` that ignores closure properties. SwiftUI reuses old view hierarchy (including old closures) when equatable says "same". Safe because @State/@Binding references are stable across renders.

### Equatable WindowTabBar (build 126)
- **What**: WindowTabBar rendered 22 times per stream (once per ConversationView parent evaluation, ~11 per window).
- **Root cause**: Already a separate struct but without Equatable conformance. Parent recreation always triggered body evaluation because closure property prevented SwiftUI's automatic diffing.
- **Fix**: Added Equatable conformance comparing display properties only (activeType, envConnected, totalCost, folderName, repoPath, environmentId). Added `.equatable()` at call site.
- **Numbers**: WindowTabBar renders: 22 → 2. ConvView renders also dropped: 21 → 11 (side effect of equatable child reducing layout recalculation pressure).
- **Pattern**: Same closure-ignoring Equatable pattern. Include filtering properties (repoPath, environmentId) in equality to ensure correct data when switching contexts.

### Guard toolCalls mutations + reduce display link rate (build 127)
- **What**: During text streaming, `completeTopLevelExecutingTools()` was called on every text chunk, reassigning `toolCalls` via `@Published` even when no tools were executing. Display link fired at 60fps for text draining when 30fps produces identical visual quality.
- **Root cause**: `completeTopLevelExecutingTools()` and `completeExecutingTools()` always mapped the full toolCalls array and reassigned it, firing `@Published`. With 60fps display link, this meant 60 unnecessary Combine events/sec to every ObservedMessageBubble during text-only chunks. Also removed unused `windowManager` @ObservedObject from ConversationSearchSheet.
- **Fix 1**: Added `guard toolCalls.contains(where:)` early returns to both `completeExecutingTools()` and `completeTopLevelExecutingTools()`. No-op when nothing needs completing.
- **Fix 2**: Set `link.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)` on the text drain display link. Halves publisher event volume. At 300-1200 chars/sec, 30fps means 10-40 chars per tick, imperceptible vs 60fps.
- **Fix 3**: Removed unused `@ObservedObject var windowManager` from ConversationSearchSheet. Prevents unnecessary re-renders when windowManager publishes while search sheet is open.
- **Pattern**: Guard mutations on @Published properties with a contains check before map+reassign. Reduce display link frame rate when the visual effect doesn't benefit from 60fps. Remove unused @ObservedObject subscriptions.
