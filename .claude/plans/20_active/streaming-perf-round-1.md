# Streaming Perf Round 1

Tags: performance

## Goal
- Metric: `LiveBubble` renders during `mixed-markdown-multi-tool.txt`
- Baseline target: `330` renders on commit `636a207f`
- Success threshold: reduce to `<220` renders while keeping the same scenario output correct and keeping steady-state FPS at `>=55`

## Scope
- Area under investigation: live streaming render churn in the conversation path on the current stable refactor-era build
- Files likely involved:
  - `Cloude/Cloude/Features/Conversation/Views/MessageBubble+LiveWrapper.swift`
  - `Cloude/Cloude/Features/Conversation/Views/MessageBubble.swift`
  - `Cloude/Cloude/Features/Conversation/Views/ConversationView.swift`
  - `Cloude/Cloude/Features/Conversation/Store/ConversationStore+Messaging.swift`
- Constraints:
  - no tool-group behavior regressions
  - no completion-handoff regressions
  - keep the current stable user-visible behavior that was just validated on-device

## Prior Art
- Relevant done plans:
  - `.claude/plans/40_done/window-tab-rerender-fix.md`
  - `.claude/plans/40_done/unified-streaming.md`
- Patterns reused:
  - render-count comparison via `debug-metrics.log`
  - FPS and `owcPerSec` samples via `app-debug.log`
  - canonical mixed-content scenario runner

## Reproduction
- Scenario: `mixed-markdown-multi-tool.txt`
- Model: `haiku`
- Steps:
  - run `.claude/skills/optimize-performance/scripts/run-perf-scenario.sh --scenario mixed-markdown-multi-tool.txt --wait 45`
  - use the built-in summary from `summarize-render-logs.sh`
  - compare only against the same scenario and same logs

## Instrumentation
- Mode: baseline
- Persistent logs used:
  - `debug-metrics.log`
  - `app-debug.log`
- Temporary probes added:
  - none
- Logs cleared before each run:
  - yes, by the scenario runner

## Baseline
- Build or commit context: `636a207f` on `experiment-refactor-no-perf`, already pushed to `main`
- Before numbers:
  - `LiveBubble: 330 renders`
  - `ConvView: 32 renders`
  - `MainChat: 16 renders`
  - `WindowTabBar: 2 renders`
  - `InputBar: 19 renders`
  - FPS samples: one early `55`, one early `47`, then steady `60-61`
  - `owcPerSec`: `3` once, then `0` in the sampled tail
- Notes:
  - baseline uses the current stable streaming/tool behavior
  - this round starts after the major streaming regressions were removed

## Hypothesis
- Suspected root causes:
  - `ObservedMessageBubble` republishes the full live `toolCalls` array even when only hidden result payload changes
  - parent `MainChat` and `ConvView` rerenders still flow into unchanged live rows because the row lacks an equatable boundary
- Why this metric moves:
  - the inline streaming path only depends on visible tool identity and state
  - once hidden payload churn is filtered, the remaining exact duplicate live renders should mostly be parent-driven and removable with a row boundary

## Investigator Notes
- Summary:
  - current branch is stable enough to resume perf work
  - the first safe target is `LiveBubble`, not tool-group logic or completion handoff
  - after the first fix, the residue was `25` exact duplicate live assistant renders out of `251`
  - those duplicates aligned with `MainChat` and `ConvView` rerenders while the live message state was unchanged

## Proposed Fix
- Step 1: in `ObservedMessageBubble`, only update `liveToolCalls` when the visible render projection changes: `name`, `input`, `toolId`, `parentToolId`, `textPosition`, `state`, `editInfo`
- Step 2: add a row-level equatable boundary around `ObservedMessageBubble` so unchanged parent passes do not rebuild the live row
- Alternatives rejected:
  - reintroducing tool-call frozen splitting
  - reintroducing adaptive live-text throttling
  - reintroducing group-level tool strip equality
- Risks:
  - could accidentally hide legitimate visible tool updates if the projection leaves out a field used by the inline strip
  - could over-freeze the live row if the equatable boundary ignores a real visible input

## Consultation
- Model consulted: Codex read-only via local `codex exec`
- Challenge raised:
  - do not assume local `@State` mirroring itself is the whole bug
  - avoid touching tool-group or completion logic in this round
  - prefer the smallest change that narrows visible-state churn only
- What changed after consult:
  - narrowed the candidate fix from general live-wrapper refactoring to a projection filter, then only added a row boundary after the logs proved the remaining duplicates were parent-driven

## Implementation
- Files changed:
  - `Cloude/Cloude/Features/Conversation/Views/MessageBubble+LiveWrapper.swift`
  - `Cloude/Cloude/Features/Conversation/Views/ConversationView+MessageScroll.swift`
- Temporary instrumentation removed: none
- Notes:
  - `liveText` now ignores duplicate assignments
  - `liveToolCalls` now ignores updates that only change hidden payload fields like `resultSummary` and `resultOutput`
  - `ObservedMessageBubble` is now `Equatable`
  - the message list now wraps `ObservedMessageBubble` in `.equatable()`

## After Measurement
- After numbers:
  - `LiveBubble: 247 renders`
  - `ConvView: 32 renders`
  - `MainChat: 16 renders`
  - `WindowTabBar: 2 renders`
  - `InputBar: 19 renders`
  - FPS samples: `58`, `52`, `53`, then steady `60-61`
  - `owcPerSec`: `3` once, then `0` in the sampled tail
- Comparison to baseline:
  - `LiveBubble` improved by `83` renders, about `25.2%`
  - other top-level render counts stayed flat
  - steady-state FPS remained in the same healthy range
- Residue analysis:
  - live assistant renders in the final run: `245`
  - unique visible live assistant states: `227`
  - exact duplicate live assistant renders: `18`
- Remaining gap:
  - still above the `<220` target
  - the remaining gap is now much smaller and likely closer to real visible update cost than pure churn

## Solver Notes
- Summary:
  - both changes are real wins and appear safe
  - the round materially reduced `LiveBubble` churn without reopening the tool or completion regressions

## Reviewer Verification
- Scenario rerun: completed with the same canonical script and wait time
- Methodology matched: yes
- Numbers verified: yes

## Regression Check
- Cases exercised:
  - canonical mixed markdown plus multi-tool scenario
  - same stable branch and same logs as baseline
- Regressions found:
  - none in the scenario run

## Shared Artifact Update
- File updated: none
- Why it changed: current canonical scenario already reproduces the issue cleanly
- What future round it should help catch: a later round may update the skill if a better probe becomes necessary

## Decision
- Status: keep
- Reason: measurable `LiveBubble` reduction with stable scenario behavior and no observed regressions in the canonical run

## Reviewer Notes
- Summary: round 1 produced a safe incremental win and should stay in the branch
