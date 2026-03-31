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
