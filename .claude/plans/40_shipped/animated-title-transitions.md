# Animated Title Transitions {textformat.abc}
<!-- priority: 10 -->
<!-- tags: ui, header -->
<!-- build: 82 -->

> Animated conversation name and symbol changes in the header pill with numericText and symbolEffect transitions.

Animate conversation name and symbol changes in the header pill instead of instant swap.

## Changes
- `MainChatView+ConversationInfo.swift`: Added `.contentTransition(.numericText())` on name text and `.contentTransition(.symbolEffect(.replace))` on SF Symbol icon
