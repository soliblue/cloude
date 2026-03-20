# Scroll to bottom timing fix
<!-- build: 96 -->

Changed scroll trigger from `messages.count` to `messages.last?.id` and added `await Task.yield()` so the scroll fires after SwiftUI has laid out the new message row.

## Desired Outcome
Scroll to bottom reliably includes the newly sent message row.

**Files:** `Cloude/Cloude/UI/ConversationView+Components.swift`
