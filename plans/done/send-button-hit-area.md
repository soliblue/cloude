# Send Button Hit Area + Pill Style
<!-- priority: 10 -->
<!-- tags: input -->
<!-- build: 56 -->

Redesigned the send/action button as a prominent pill:
- **Filled circle** with accent background + white icon when active (can send or stop)
- **Transparent** with dimmed accent icon when inactive (nothing to send)
- Shared style across all states: send (paperplane), queue (clock), stop (stop)
- 36pt circle with 8pt inset expansion for generous hit area
- Animated transitions between states

**Changed**: `GlobalInputBar.swift` — extracted `actionButtonLabel` and `actionButtonIcon` shared across all button states.
