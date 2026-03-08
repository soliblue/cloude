# Queued Messages Block Scroll

## Problem
When queued messages are visible in the conversation, scrolling the chat becomes difficult or broken. The `SwipeToDeleteBubble`'s `DragGesture` intercepts vertical scroll gestures, preventing normal ScrollView scrolling.

## Root Cause
`ConversationView+Components.swift:SwipeToDeleteBubble` uses a `DragGesture(minimumDistance: 10)` that captures drag events before the parent ScrollView can handle them. The gesture only filters for horizontal direction (`translation < 0`) inside `onChanged`, but by then it has already claimed the gesture from the ScrollView.

## Proposed Fix
In `SwipeToDeleteBubble`, two changes:
1. Increase `minimumDistance` from 10 to 20 — gives ScrollView more room to claim vertical drags
2. Add direction detection with `dragDecided`/`isHorizontalDrag` state — on first movement, check if `horizontal > vertical * 1.5`. Only activate swipe-to-delete if clearly horizontal. Reset both flags in `onEnded`.

This keeps swipe-to-delete working while letting vertical scrolls pass through to the ScrollView.
