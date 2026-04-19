---
title: "Smart Reply Bubbles"
description: "Replaced ghost-text autocomplete with tappable suggestion bubbles that appear above the input bar when agent goes idle."
created_at: 2026-02-07
tags: ["input", "ui"]
icon: text.bubble
build: 45
---


# Smart Reply Bubbles
Replace inline ghost-text autocomplete with contextual suggestion bubbles.

## What Changes

**Before**: Type 3+ chars → Haiku completes your sentence → ghost text → right-swipe to accept
**After**: Claude finishes responding → 2 short suggestion bubbles appear above input → tap to fill input

## Behavior

- Appear when agent goes idle AND input is empty
- Show exactly 2 suggestions — short, conversational (like "Push to git", "Run the tests", "Looks good, deploy it")
- Tapping a bubble fills `inputText` with that text (user can edit or just send)
- Disappear when: user starts typing, agent starts running, or user switches windows
- Don't appear on heartbeat page (page 0)
- Don't appear if conversation has no messages yet (empty state)

## Files to Change

### Shared Protocol
- **`ServerMessage.swift`**: Change `autocompleteResult` → `suggestionsResult(suggestions: [String], conversationId: String?)`
- **`ClientMessage.swift`**: Change `autocomplete` → `requestSuggestions(context: [String], workingDirectory: String?, conversationId: String?)`

### Mac Agent (Server)
- **`AutocompleteService.swift`**: Replace `complete()` with `suggest()` — new prompt asking for 2 short follow-up suggestions as JSON array. Keep Haiku model.
- **`AppDelegate+MessageHandling.swift`**: Update handler for new message type

### iOS App (Client)
- **`MainChatView.swift`**: Replace `autocompleteSuggestion: String` with `suggestions: [String]`. Trigger request when agent goes idle (not on typing). Pass to GlobalInputBar.
- **`MainChatView+Utilities.swift`**: Replace `setupAutocompleteHandler`/`requestAutocomplete` with `setupSuggestionsHandler`/`requestSuggestions`. Send more context (last 6 messages).
- **`GlobalInputBar.swift`**:
  - Remove ghost text overlay, right-swipe gesture for autocomplete, typing-triggered debounce
  - Add suggestion bubbles row above input bar (only when `inputText.isEmpty` and suggestions exist)
  - Two horizontally scrolling capsule buttons
- **`ConnectionManager+API.swift`**: Replace `requestAutocomplete` with `requestSuggestions`, update handler

## UI Design

```
┌─────────────────────────────────┐
│  [Push to git]  [Looks good]    │  ← capsule buttons, subtle style
├─────────────────────────────────┤
│  [         input bar          ] │
└─────────────────────────────────┘
```

Capsule style: `.ultraThinMaterial` background, rounded pill shape, secondary text color, ~13pt font. Tap fills input.
