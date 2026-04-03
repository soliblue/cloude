# Streaming Perf Round 4

tags: performance
status: accepted

## Goal
Trim remaining hot-path container inputs after the hidden-window freeze.

## Reproduction
- `.claude/skills/optimize-performance/scripts/run-perf-scenario.sh --scenario mixed-markdown-multi-tool.txt --wait 45`

## Instrumentation
- Baseline render logging via `debugOverlayEnabled`
- Sources: `LiveBubble`, `ConvView`, `MainChat`, `WindowTabBar`, `InputBar`

## Baseline Numbers
- Starting point: local commit `5bb5b254`
- `LiveBubble: 277`
- `ConvView: 13`
- `MainChat: 13`
- `WindowTabBar: 2`
- `InputBar: 16`

## Root-Cause Hypothesis
Several dead props still flowed through the active chat path and widened invalidation even though the active-chat scenario never used them: `showHeader`, `agentState`, `onNewConversation`, and `conversationDefaultModel`.

## Fix
Remove the dead props from `ConversationView`, `ChatMessageList`, `WorkspaceInputBar`, and the corresponding call sites.

## Consultation Summary
Used only properties proven unused by code search, so the round stayed a structural cleanup instead of a behavior change.

## After Numbers
Run 1:
- `LiveBubble: 217`
- `ConvView: 12`
- `MainChat: 12`
- `WindowTabBar: 2`
- `InputBar: 15`

## Regression Results
- Canonical mixed streaming scenario still completed normally.
- Build stayed green after the call-site cleanup.
- No user-facing behavior in the active-chat path depended on the removed props.

## Approval
Accepted.

## Shared Artifact Updated
- Added this round note so later rounds can treat dead hot-path props as already pruned.
