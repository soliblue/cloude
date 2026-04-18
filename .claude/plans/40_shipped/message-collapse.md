---
title: "Message Collapse"
description: "Added long-press collapse/expand for assistant messages with persistent state."
created_at: 2026-02-10
tags: ["ui", "streaming"]
icon: rectangle.compress.vertical
build: 70
---


# Message Collapse {rectangle.compress.vertical}
## Implementation
- `isCollapsed: Bool` on `ChatMessage` model (Codable, defaults to `false`)
- Context menu: "Collapse" / "Expand" toggle for assistant messages
- When collapsed: `frame(maxHeight: 120)` + `.clipped()` + gradient fade overlay
- "Show more" button with chevron below collapsed content
- `onToggleCollapse` callback → `ConversationStore.updateMessage` for persistence
- `replaceMessages` merge preserves `isCollapsed` on history sync

## Files Changed
- `Conversation.swift` — added `isCollapsed` to `ChatMessage`
- `ChatView+MessageBubble.swift` — collapse UI, context menu, gradient fade
- `ConversationView+Components.swift` — `toggleCollapse` wiring
- `ConversationStore+Operations.swift` — preserve `isCollapsed` in merge
