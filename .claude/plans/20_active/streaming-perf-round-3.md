# Streaming Perf Round 3

tags: performance
status: accepted

## Goal
Reduce hidden inactive-window rerenders during the canonical mixed streaming scenario.

## Reproduction
- `.claude/skills/optimize-performance/scripts/run-perf-scenario.sh --scenario mixed-markdown-multi-tool.txt --wait 45`

## Instrumentation
- Baseline render logging via `debugOverlayEnabled`
- Sources: `LiveBubble`, `ConvView`, `MainChat`, `WindowTabBar`, `InputBar`

## Baseline Numbers
- Starting point: local commit `c1b30623`
- `LiveBubble: 242`
- `ConvView: 24`
- `MainChat: 12`
- `WindowTabBar: 2`
- `InputBar: 15`

## Root-Cause Hypothesis
The workspace still reevaluated hidden pages during active-chat streaming. The paired `ConvView render | msgs=1` and `ConvView render | msgs=2` logs indicated the inactive window was paying for the active window's updates.

## Fix
Wrap only inactive window pages in an equatable boundary keyed by a narrow window snapshot, while leaving the active page fully live.

## Consultation Summary
Used a boundary only on hidden pages to avoid the earlier regression class where the active page stopped updating correctly.

## After Numbers
Run 1:
- `LiveBubble: 277`
- `ConvView: 13`
- `MainChat: 13`
- `WindowTabBar: 2`
- `InputBar: 16`

## Regression Results
- Canonical mixed streaming scenario still completed normally.
- No change to the active page render path.
- Regression risk remains around cross-window state preservation and should be checked on-device before any push.

## Approval
Accepted for local testing only.

## Shared Artifact Updated
- Added this round note so later work can distinguish active-page churn from hidden-page churn.
