# Keyboard Dismiss Animation
<!-- build: 86 -->

Animate input bar transition when keyboard dismisses instead of snapping instantly.

## Changes
- `MainChatView.swift`: Wrap `isKeyboardVisible` state changes in `withAnimation` using the keyboard notification's duration/curve
- Added `keyboardAnimation(from:)` helper that extracts iOS keyboard animation parameters

## Test
- Open keyboard by tapping input bar
- Dismiss keyboard (swipe down or tap outside)
- Input bar should smoothly animate back to bottom instead of snapping
