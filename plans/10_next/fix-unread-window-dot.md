# Fix Unread Window Dot

## Problem
The unread dot below window icons in the switcher doesn't reliably appear. The root cause: `markUnread` only fires on `conversationOutputStarted`, which triggers once when `isRunning` flips to `true`. If you're still viewing the window when the first output chunk arrives (which is almost always the case — you send a message and see the response start), the condition `window.id != activeWindowId` is false, so `markUnread` never gets called. Then you swipe away, streaming continues/finishes, but nothing marks it unread.

## Fix
In the `onChange(of: currentPageIndex)` handler in `MainChatView.swift` (line ~232), when leaving a window that's currently streaming, call `markUnread` on it:

```swift
if oldIndex > 0 {
    let oldWindowIndex = oldIndex - 1
    if oldWindowIndex < windowManager.windows.count {
        let oldWindow = windowManager.windows[oldWindowIndex]
        if let convId = oldWindow.conversationId,
           connection.output(for: convId).isRunning {
            windowManager.markUnread(oldWindow.id)
        }
    }
}
```

Zero performance cost — runs once on swipe, not per character. The dot appears when you leave, stays until you come back (`markRead` on page change handles clearing).

## Bonus: Reclaim vertical space
Once this works reliably, move the unread indicator from a dot *below* the icon to a small badge overlay *on top* of the icon (like the heartbeat's unread count badge). This removes ~10pt of vertical space from every switcher button, shrinking the overall switcher height.

## Files
- `MainChatView.swift` — `onChange(of: currentPageIndex)` handler (~line 232)
- `MainChatView+PageIndicator.swift` — move dot to overlay (bonus)
