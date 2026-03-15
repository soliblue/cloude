# Scroll Position Bugs

Multiple scroll-related issues in ConversationView. Needs investigation before fixing.

## Reported Symptoms

### 1. Scrolled past messages on chat switch
When switching chats via the switcher, sometimes lands at a position with no visible messages. User has to scroll up to find the conversation content.

### 2. Scrolled past messages during active use
Same "no messages visible" issue happens when sending a message or while receiving a streaming response. Not tied to conversation switching.

### 3. Scroll-to-bottom button missing on app restart
After restarting the app (especially on long conversations), the scroll-to-bottom button doesn't appear. Only shows up after manually scrolling to bottom first, then scrolling back up.

### 4. Scroll-to-bottom button doesn't work
When the button does appear on long conversations, tapping it sometimes doesn't scroll to the bottom.

## Hypothesis

The scroll system relies on a `bottomId` sentinel (`Color.clear.frame(height: 80)`) at the end of a `LazyVStack`. Several interacting mechanisms could cause these issues:

- **`isBottomVisible` tracked via `onAppear`/`onDisappear` on the sentinel** - in a LazyVStack, this view may not be loaded yet on app restart for long convos, so `isBottomVisible` starts `true` (default) even though it's not actually visible. This would hide the scroll-to-bottom button.
- **`scrollTo(bottomId)` fails if the sentinel isn't loaded** - LazyVStack doesn't load offscreen views. If the bottom sentinel hasn't been realized by SwiftUI, `scrollTo` silently fails. This explains symptom #4.
- **`onChange(of: conversationId)` resets state but doesn't scroll** - when switching chats, `userHasScrolled` and `isInitialLoad` reset, but no `scrollTo` is triggered. The `onAppear` scroll only fires once when the view is first mounted.
- **Race conditions with streaming** - the `onChange(of: currentOutput)` auto-scroll requires `isBottomVisible && !userHasScrolled`. If either flag is wrong, auto-scroll stops working mid-conversation.

## Investigation Plan

1. Add temporary logging to track `isBottomVisible`, `userHasScrolled`, `isInitialLoad` state transitions
2. Test each symptom in isolation
3. Check if LazyVStack vs VStack matters for the sentinel loading
4. Consider replacing `onAppear`/`onDisappear` tracking with `ScrollPosition` API (iOS 18+) or GeometryReader-based approach

## Files
- `Cloude/Cloude/UI/ConversationView+Components.swift` (all scroll logic lives here)
