# Preserve scroll position when switching tabs

`onAppear` on the `ScrollViewReader` unconditionally scrolls to the bottom every time it fires — but it fires in two distinct situations, both of which lose the user's reading position.

**File:** `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/UI/ConversationView+Components.swift` lines 140-147

```swift
.onAppear {
    scrollProxy = proxy
    if !messages.isEmpty {
        isInitialLoad = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            proxy.scrollTo(bottomId)  // fires every time view appears, not just initial load
        }
    }
}
```

**Trigger 1 — chat/files tab switcher**: `pagedWindowContent` uses a `switch window.type`, so `ConversationView` is fully destroyed and recreated on each switch. `onAppear` fires on recreation.

**Trigger 2 — page switcher (heartbeat ↔ windows)**: `TabView` with `.page` style keeps views alive (state is preserved), but `onAppear` still fires as a visibility event whenever a page comes back into view. So switching from window 1 → window 2 → window 1 also triggers the scroll.

The `onAppear` intent is to scroll to bottom on first load — but it fires unconditionally on both triggers.

## Desired behaviour
Switching to files and back should restore scroll position. Only scroll to bottom on genuine first load (no prior view state).

## Options

**Option A — gate scroll on `isInitialLoad`**
The `isInitialLoad` flag already exists for this purpose. The `onAppear` scroll should only run when `isInitialLoad` is true:
```swift
.onAppear {
    scrollProxy = proxy
    if !messages.isEmpty && isInitialLoad {
        isInitialLoad = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            proxy.scrollTo(bottomId)
        }
    }
}
```
Simple, minimal change. Risk: `isInitialLoad` is reset by other paths — need to verify it stays false across tab switches.

**Option B — hoist view state out of `ConversationView`**
Move `isInitialLoad`, `userHasScrolled`, `isBottomVisible` into the parent (`pagedWindowContent` or a view model) so they survive the destroy/recreate cycle. Tab switch no longer loses state because state lives above the view. Cleaner long-term but larger change.

**Option C — keep `ConversationView` alive across tab switches**
Use `ZStack` with opacity toggling instead of `switch` so both views stay in the hierarchy. Avoids the destroy/recreate entirely. Tradeoff: both views always rendered (memory cost), `FileBrowserView` persists in background.

## Recommendation
Option A is the right immediate fix — `isInitialLoad` exists precisely for this. Option B is the right architectural fix if scroll state management gets more complex.

## Note
For Option A, since `TabView` preserves `@State` across page switches, `isInitialLoad` will correctly remain `false` when switching back via the page switcher — the fix works for both triggers with no extra effort.
