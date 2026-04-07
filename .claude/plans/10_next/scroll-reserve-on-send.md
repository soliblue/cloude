# Scroll Reserve on Send {arrow.up.to.line}
<!-- priority: 10 -->
<!-- tags: ui, streaming -->
> Pin the user's message to the top of the viewport after sending, reserving the full screen for the streaming response (like ChatGPT).

## Problem

Currently when a message is sent, it appends to the bottom of the list and the streaming response grows the last bubble downward. The user message stays near the bottom with the response pushing content up via auto-scroll. This means constant scrolling as the response streams, and the user message quickly disappears off the top.

ChatGPT solves this by positioning the user's message at the top of the viewport after send, with the entire screen below reserved for the incoming response. The response fills in from the top of that empty space, avoiding unnecessary scroll until it actually exceeds the viewport.

## Proposal

Use `ScrollViewReader` with a two-phase scroll strategy:

1. **On send**: `scrollTo(userMessageId, anchor: .top)` positions the user message at the top of the viewport, leaving the full screen below for the response
2. **During streaming (short response)**: viewport stays put, response grows downward in the available space
3. **During streaming (long response)**: once the response exceeds viewport height, switch to `scrollTo(liveBubbleId, anchor: .bottom)` to follow the latest content
4. **After streaming**: normal scroll behavior resumes

### Why not a spacer?

A fixed-timer spacer (animating from 65% screen height to 0) was prototyped but has issues:
- `.defaultScrollAnchor(.bottom)` fights the shrinking spacer, causing unpredictable scroll
- Fixed animation duration doesn't match variable response speed
- Spacer collapses too early or too late depending on response length

The stashed prototype is at `git stash list` under "chatgpt-style scroll reserve spacer".

### Key files

- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Conversation/Views/ConversationView+MessageScroll.swift`
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Conversation/Views/ConversationView+Components.swift`

### Open questions

- How to detect "response exceeds viewport" without GeometryReader (removed for perf)?
- Should the phase-2 to phase-3 transition be based on character count, line count, or something else?
- What happens if the user manually scrolls during streaming? Should auto-scroll stop?
