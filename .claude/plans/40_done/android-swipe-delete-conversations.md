# Android Swipe-to-Delete Conversations {trash}
<!-- priority: 12 -->
<!-- tags: android, conversations, ux -->

> Swipe gesture to delete conversations from the list.

## Desired Outcome
Swipe right on a conversation row in the conversation list sheet to reveal a red delete button. Familiar gesture pattern for quick conversation cleanup.

## iOS Reference Architecture

### Components
- `WindowEditSheet+Form+ConversationList.swift` - SwipeToDeleteRow with drag gestures

### Android implementation notes
- Use `SwipeToDismissBox` from Material3 on `ConversationRow` in `ConversationListSheet`
- Red background with trash icon revealed on swipe
- Confirm delete or auto-delete on full swipe
- Replace current delete `IconButton` which requires precise tap

**Files (iOS reference):** WindowEditSheet+Form+ConversationList.swift
