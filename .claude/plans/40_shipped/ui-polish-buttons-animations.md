---
title: "UI Polish - Button States and Animations"
description: "Added button disable states, rotation/checkmark animations, line numbers in file preview, and empty state env selector."
created_at: 2026-03-10
tags: ["ui"]
icon: wand.and.stars
build: 82
---


# UI Polish - Button States and Animations {wand.and.stars}
## Changes
- Disable refresh button when environment is not connected
- Disable terminal send button when environment is not connected
- Add rotation animation to refresh button on click (SF Symbol `.rotate` effect)
- Add checkmark animation to export/share button (same as code block copy)
- Add checkmark animation to message bubble copy button (`.symbolEffect(.replace)`)
- Remove redundant "Copied" toast from message bubble (checkmark animation replaces it)
- Add line numbers to file preview source view (respects `showCodeLineNumbers` setting)
- Improve empty chat view with env selector and folder picker below Claude character

## Files Changed
- `MainChatView.swift` - added `refreshTrigger`, `exportCopied` state
- `MainChatView+Windows.swift` - refresh disable logic, rotation animation, export animation, `environmentDisconnected` helper, pass `environmentStore` to ConversationView
- `TerminalView.swift` - `isEnvironmentConnected` check, disable send when disconnected
- `MessageBubble.swift` - checkmark animation on copy button, removed toast overlay
- `FilePreviewView.swift` - added `showLineNumbers` AppStorage
- `FilePreviewView+Content.swift` - line number column in source text view
- `ConversationView.swift` - added `environmentStore` parameter, pass through to ChatMessageList
- `ConversationView+Components.swift` - added `environmentStore` to ChatMessageList, pass to EmptyConversationView
- `ConversationView+EmptyState.swift` - env selector menu + folder picker below Claude character (only for new conversations)
