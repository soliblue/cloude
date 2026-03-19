# Window Header Cleanup

The window header is cluttered with rarely-used buttons. Strip it down and redistribute actions to more natural touch targets.

## Current State

**Header**:
```
[chat] [files] [git] [term]   ·   (env●)   ·   [copy] | [fork] | [↺] | [✕]
```
Long press on bottom bar window icon → opens WindowEditSheet

## Target State

**Header** — type switcher + tappable chat name:
```
[chat] [files] [git] [term]   [symbol] ConversationName • folder
```
Tap the name area → opens WindowEditSheet (rename, link conversation)

**Bottom bar window icon**:
- Tap → navigate (unchanged)
- Long press → context menu:
  - Refresh
  - Export (copy to clipboard)
  - Fork
  - Close

## What Gets Removed from Header
- Env connect/disconnect circle button (input bar handles this)
- Export (doc.on.doc)
- Fork (arrow.triangle.branch)
- Refresh (arrow.clockwise)
- Close (xmark)

## Implementation

1. **`MainChatView+Windows.swift`** — `windowHeader`:
   - Remove entire right-side button group
   - Remove env circle button
   - Add `WindowHeaderView` (conversation name pill) to the right of the type switcher, wired to `editingWindow = window`

2. **`MainChatView+PageIndicator.swift`** — `windowIndicatorButton`:
   - Replace `LongPressGesture` (currently opens edit sheet) with `.contextMenu`:
     ```swift
     .contextMenu {
         Button("Refresh") { refreshConversation(for: window) }
         Button("Export") { exportConversation(conv) }
         Button("Fork") { /* duplicate */ }
         Button("Close", role: .destructive) { windowManager.removeWindow(window.id) }
     }
     ```

## Files
- `Cloude/Cloude/UI/MainChatView+Windows.swift` — strip `windowHeader`, add name tap
- `Cloude/Cloude/UI/MainChatView+PageIndicator.swift` — swap long press for `.contextMenu`
- `Cloude/Cloude/UI/MainChatView+ConversationInfo.swift` — `WindowHeaderView` already exists, just wire it up
