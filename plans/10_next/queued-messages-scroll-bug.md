# Queued Messages Block Scroll

## Problem
When queued messages are visible in the conversation, scrolling the chat becomes difficult or broken. The `SwipeToDeleteBubble`'s `DragGesture` intercepts vertical scroll gestures, preventing normal ScrollView scrolling.

## Root Cause
`ConversationView+Components.swift:SwipeToDeleteBubble` uses a `DragGesture(minimumDistance: 10)` that captures drag events before the parent ScrollView can handle them. The gesture only filters for horizontal direction (`translation < 0`) inside `onChanged`, but by then it has already claimed the gesture from the ScrollView.

## Fix Ideas
- Use `simultaneousGesture` instead of `.gesture` so the ScrollView still receives the drag
- Add a direction check: only activate the swipe gesture when horizontal movement exceeds vertical (e.g., `abs(translation.width) > abs(translation.height)`)
- Increase `minimumDistance` threshold
- Use a custom `GestureState` approach that defers to ScrollView for vertical drags
