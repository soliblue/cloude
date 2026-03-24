# Launcher UX Improvements {sparkles}
<!-- build: 103 -->
<!-- priority: 10 -->
<!-- tags: ui, ux -->

## Changes
- **Full-width page indicator**: Icons spread across full screen width with equal spacing and large tap targets (44pt)
- **Plus button hidden at max**: Hide add button when all 5 window slots are used
- **Empty window cleanup**: Swiping away from an unused window now removes it entirely instead of leaving an empty slot
- **Swipe-to-delete conversations**: Swipe left on conversations in window edit sheet to reveal delete button, with proper scroll/tap coexistence
- **Hidden scrollbar**: Removed scroll indicator from window edit sheet

## Files
- `MainChatView+PageIndicator.swift` - full-width layout, ForEach over windows.indices + separate plus button
- `MainChatView+Utilities.swift` - `cleanupEmptyConversation` now calls `removeWindow` instead of `unlinkConversation`
- `WindowEditSheet+Form+ConversationList.swift` - `SwipeToDeleteRow` component, conversation row refactor
- `WindowEditSheet.swift` - hidden scrollbar
