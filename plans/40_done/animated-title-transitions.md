# Animated Title Transitions
<!-- build: 82 -->

Animate conversation name and symbol changes in the header pill instead of instant swap.

## Changes
- `MainChatView+ConversationInfo.swift`: Added `.contentTransition(.numericText())` on name text and `.contentTransition(.symbolEffect(.replace))` on SF Symbol icon
