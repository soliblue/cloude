# Short conversations fill screen properly

## Problem
When a conversation had few short messages, the messages floated at the bottom of the screen with empty space above (due to `.defaultScrollAnchor(.bottom)`).

## Fix
Wrapped the `LazyVStack` in a `VStack` with a `Spacer` below and `.frame(minHeight: scrollViewportHeight)`. Messages now sit at the top, with empty space filling below. When content exceeds the viewport, scrolling works normally.

## Files
- `Cloude/Cloude/UI/ConversationView+Components.swift`
