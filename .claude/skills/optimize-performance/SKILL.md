---
name: optimize-performance
description: "Run measured SwiftUI performance investigations through investigator, solver, and reviewer passes with proof-based before/after verification."
user-invocable: true
metadata:
  icon: gauge.with.dots.needle.bottom.50percent
  aliases: [perf, optimize, rerender, re-render]
argument-hint: "[view or area to optimize]"
---

# Optimize Performance

Run performance work as explicit rounds. Each round gets one plan document, one measured problem statement, one fix attempt, and one reviewer decision backed by proof.

## Core Rules

- Measure first, optimize second. No guessing.
- Every round starts with an investigator-created plan doc.
- Investigators may add instrumentation, never logic changes.
- Solvers must consult the other model before implementing.
- Reviewers rerun the measured scenario and broader regressions.
- Proof requires same scenario, same logging method, and concrete before/after numbers.
- Remove unnecessary instrumentation and throwaway changes once the proof is captured.
- If review fails, the round returns to investigation.
- When review passes, move the plan to done and make a local commit. Do not push.
- Tag every accepted round with `performance`.
- Every accepted round must improve at least one shared artifact: a scenario, a script, a logging helper, or an optimization note in this skill.

## File Layout

- `SKILL.md`: orchestrates the workflow and stores shared performance knowledge.
- `roles/investigator.md`: creates the plan, instrumentation, baseline, and hypothesis.
- `roles/solver.md`: proposes the fix, consults the other model, implements, and measures after.
- `roles/reviewer.md`: validates proof, runs regression coverage, and approves or rejects.
- `templates/perf-plan.md`: required structure for every round document.
- `scripts/`: editable helpers for baselines, regressions, and log summaries.
- `scenarios/`: editable prompts that stress known-danger rendering paths.
- `references/`: checklists and shared instrumentation guidance.

## Round Lifecycle

1. Investigator creates a new plan doc under `.claude/plans/20_active/` using `templates/perf-plan.md`.
2. Investigator reads prior art, picks or extends the relevant scenario, adds only the instrumentation needed, reproduces the issue, and records baseline numbers.
3. Solver reads the plan, proposes the smallest fix that addresses the measured cause, consults the other model, implements, and records after numbers.
4. Reviewer reruns the baseline scenario, runs regression coverage, and checks the methodology and behavior.
5. If reviewer rejects, move ownership back to investigator and remove weak changes.
6. If reviewer accepts, update the shared script, scenario, or logging artifact learned from the round, move the doc to `.claude/plans/40_done/`, and make a local commit.
7. Append the biggest win, pattern, or pitfall from the round to the Optimization Log in this file.

## Required Plan Discipline

Every round must have exactly one active plan document. Keep role updates high level and append only what is necessary to make the next handoff unambiguous.

The plan must always contain:

- a concrete goal with a number
- exact reproduction steps
- instrumentation used
- baseline numbers
- root-cause hypothesis
- proposed fix
- consultation summary
- after numbers
- regression results
- approval or rejection
- shared artifact updated by the round

## Prior Art

Read these done plans before starting. They document existing patterns and previous tradeoffs.

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

## Role Execution

Read and follow the role file that matches the current pass:

- `roles/investigator.md`
- `roles/solver.md`
- `roles/reviewer.md`

If one model handles multiple passes in a row, still obey the role boundaries. Do not skip the artifacts because the same model is carrying the work.

## Shared Artifacts

These files are meant to change as the team learns:

- `scenarios/mixed-markdown-multi-tool.txt`: canonical mixed-content stress case.
- `scenarios/deep-trace-checklist.md`: prompts and behaviors worth tracing when a round gets weird.
- `scripts/run-perf-scenario.sh`: boots the simulator, opens the repo conversation, sends a scenario, and summarizes logs.
- `scripts/run-perf-regression.sh`: reviewer regression entry point.
- `scripts/summarize-render-logs.sh`: quick counts from debug logs.
- `references/logging-checklist.md`: what to log in baseline mode and deep-trace mode.

When a round finds a new breakage shape, update the artifact that should catch it next time.

## Instrumentation Modes

Use two logging levels instead of one giant permanent firehose.

### Baseline instrumentation

Use this by default for comparable before and after numbers.

- render counts by source
- FPS samples
- objectWillChange rate
- key state transitions
- timing around the target path only when the metric depends on it

### Deep trace mode

Use this when baseline numbers show a problem but the cause is still unclear.

- every meaningful view re-render in the affected path
- event ordering around live-to-static handoff
- tool-group lifecycle updates
- parser split movement
- state transitions that can fan out renders
- any temporary probes needed to explain the baseline

Deep trace is for diagnosis, not permanent noise. Remove or narrow it once the round proves the cause.

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

Add `#if DEBUG` render logs to any view under investigation:

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

## Standard Simulator Flow

Start the full scenario runner with:

```bash
.claude/skills/optimize-performance/scripts/run-perf-scenario.sh
```

Useful variants:

```bash
.claude/skills/optimize-performance/scripts/run-perf-scenario.sh --scenario mixed-markdown-multi-tool.txt --wait 45
.claude/skills/optimize-performance/scripts/run-perf-scenario.sh --no-start --no-summary
.claude/skills/optimize-performance/scripts/run-perf-regression.sh
```

## Canonical Scenario Shape

The strongest default regression case mixes content types so render boundaries and parser boundaries both get stressed. The canonical scenario should include:

- markdown before any tools
- multiple tool calls in one group
- uneven tool completion timing
- markdown immediately after the tool group
- multiple paragraphs after the tools
- lists, headings, and a code fence
- enough total text to force incremental rendering behavior

Start from `scenarios/mixed-markdown-multi-tool.txt` and keep improving it when a real bug slips through.

## Reviewer Regression Coverage

Reviewers must confirm the optimized path still behaves correctly across the broader surface, not just the target metric. At minimum, exercise:

- plain markdown streaming
- heavy markdown streaming
- multiple tool calls in one group
- uneven tool durations inside one group
- agent messages
- long responses
- live-to-static handoff
- interruption or completion edge cases relevant to the change

Use haiku when possible so the regression suite stays repeatable and cheap.

## Proof Standard

A performance claim is only accepted if all of these are true:

- the before and after runs use the same scenario
- the before and after runs use the same instrumentation
- the targeted metric improves clearly
- no material behavioral regression appears in review
- the code complexity added is justified by the gain

If any of these fail, the round is not done.

## SwiftUI Notes

### Observation

- `@ObservedObject` subscribes to all `@Published` changes on the object. Every subscriber re-evaluates its body on every publish.
- `@State` changes only re-evaluate the owning view's body.
- `.onReceive(publisher)` fires the closure but does not re-evaluate the body unless `@State` changes inside it.
- `let` reference types do not create observation subscriptions. The view only re-evaluates when a parent triggers it.

### Streaming Data Flow

1. WebSocket chunks arrive -> `ConversationOutput.appendText()` -> `fullText` grows.
2. `CADisplayLink` drain at 60Hz -> `@Published var text` updates.
3. `text` publishes -> any `@ObservedObject` subscriber re-evaluates.
4. `StreamingMarkdownView` incrementally appends via `frozenBlocks` and `tailBlocks`.
5. On completion: `finalizeStreamingMessage` -> `resetAfterLiveMessageHandoff`.

### What Propagates To ConnectionManager

Only state transitions propagate up and trigger shell-level views:

- `isRunning` changes
- `isCompacting` changes
- `text` empty to non-empty or back
- `newSessionId` changes
- `skipped` changes

These do not propagate and stay local to live message observers:

- `text` content updates during drain
- `toolCalls` updates
- `runStats` updates

## Common Patterns

- Parent already observes shared state -> child should usually hold it as `let`, not `@ObservedObject`.
- Incremental append beats full re-parse when content is append-only.
- Split frozen and live regions so unchanged content can become inert.
- Measurement logic must live outside `body` when possible. Per-render allocations and derived arrays add up fast.
- A fix that improves one metric but broadens observation scope is usually not a real win.

## Common Pitfalls

- Measuring different scenarios before and after.
- Leaving temporary probes in place after the round.
- Accepting an FPS win without checking correctness.
- Fixing a symptom in the leaf while the subscription problem starts higher in the tree.
- Keeping dead cleanup code from a rejected fix attempt.

## Optimization Log

Add one short entry after every accepted round. Capture the biggest win, the root cause, the fix pattern, and the before/after numbers so the skill compounds over time.

### Streaming message re-renders (build 122)
- **What**: All message bubbles re-rendered about 60 times per second during streaming.
- **Root cause**: `@ObservedObject var output: ConversationOutput` in `ObservedMessageBubble` subscribed every message to the 60Hz text drain.
- **Fix**: `let output` plus `@State` plus `.onReceive` with guarded updates.
- **Numbers**: 9,233 to 1,036 total renders. About 8,900 to 16 wasted renders.
- **Gotcha**: `isLive` now relies on store mutations to trigger parent re-evaluation.

### Observation chain + FPS degradation (build 123)
- **What**: ConversationView double-subscribed to ConnectionManager and ConversationStore. FPS degraded from about 47 to 21 during long streams.
- **Root cause**: Child observation duplicated work already handled by the parent, and non-lazy layout cost grew with block count.
- **Fix**: Use `let` instead of `@ObservedObject`, freeze stable sections, make split-point scanning incremental, and collapse double `mutate` calls.
- **Numbers**: FPS during long stream stabilized around 55 to 61 instead of degrading to 21.
- **Pattern**: If the parent already observes the shared object, children should not subscribe again.

### Frozen split for tool calls + incremental parsing (build 124)
- **What**: Tool-call streaming responses with large text payloads degraded FPS from 60 to about 20.
- **Root cause**: Tool-call mode disabled the frozen and tail split, so the full text kept getting re-parsed.
- **Fix**: Re-enable frozen and tail splitting for tool flows, adjust tool positions relative to the tail, and move derived array work out of `body`.
- **Numbers**: Tool-call streams improved from roughly 20 to 35 degrading FPS to a stable 60 to 61.
- **Pattern**: Positional metadata can still work with region splitting if offsets are adjusted correctly.

### Adaptive streaming throttle (build 125)
- **What**: LiveBubble rendered 1,059 times per stream, dragging FPS down in the final seconds of long responses.
- **Root cause**: Every display-link text publish triggered a local state update even when rendering had become expensive.
### Remove unused keyboard invalidation from ConversationView (local round 2)
- **What**: The chat container kept rerendering around input state changes even though `ConversationView` did not use keyboard visibility.
- **Root cause**: `WorkspaceView+Windows` still passed `isKeyboardVisible` into `ConversationView`, widening invalidation scope for an unused prop.
- **Fix**: Remove the unused `isKeyboardVisible` parameter from `ConversationView` and stop passing it.
- **Numbers**: `ConvView` 32 to 24, `MainChat` 16 to 12, `InputBar` 19 to 15, with confirm run `LiveBubble` 247 to 242.
- **Pattern**: Unused props are hidden observation edges. Remove them before attempting broader row or wrapper optimizations.
### Freeze hidden window pages only (local round 3)
- **What**: Hidden windows still reevaluated their `ConversationView` during active-page streaming.
- **Root cause**: `WorkspaceView` rebuilt every page in the ZStack on each parent render, so inactive windows mirrored active-page churn.
- **Fix**: Wrap only inactive pages in an equatable boundary keyed by a narrow window snapshot and leave the active page fully live.
- **Numbers**: `ConvView` 24 to 13, `InputBar` 15 to 16, `MainChat` 12 to 13, with no observed break in the canonical mixed scenario.
- **Pattern**: If a page is fully hidden, freeze that page, not the active one.
### Prune dead hot-path props after freezing hidden pages (local round 4)
- **What**: Even after inactive pages were frozen, the active chat stack still carried several unused props through render-heavy views.
- **Root cause**: `showHeader`, `agentState`, `onNewConversation`, and `conversationDefaultModel` stayed in the active render path despite not affecting the canonical chat scenario.
- **Fix**: Remove the dead props and their call-site plumbing.
- **Numbers**: `LiveBubble` 277 to 217, `ConvView` 13 to 12, `MainChat` 13 to 12, `InputBar` 16 to 15.
- **Pattern**: After fixing the big observation edges, dead props become worth removing because they can still widen SwiftUI diffing in hot views.
### Automate reviewer regression coverage (local round 5)
- **What**: Review coverage still depended on people manually replaying the canonical scenario and the edge-case scenario after each accepted round.
- **Root cause**: `run-perf-regression.sh` only printed instructions, so the regression suite was procedural instead of enforced by the shared tooling.
- **Fix**: Make `run-perf-regression.sh` execute the canonical mixed-tool scenario plus one explicit secondary scenario, and add `agent-group-completion.txt` as the shared completion-edge case.
- **Numbers**: reviewer automation 0 to 2 scenarios per command, manual review wrapper steps 4 to 1.
- **Pattern**: If a regression check matters, encode it in the shared runner instead of leaving it as a remembered checklist.
