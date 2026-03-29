# Android Input Bar Polish {text.cursor}
<!-- priority: 13 -->
<!-- tags: android, input, ux -->

> Placeholder tip rotation, history suggestions, and @file search.

## Desired Outcome
Polish input bar to match iOS details and improve discoverability.

## Sub-features

### 1. Placeholder tip rotation
- iOS rotates through 10 tip strings every 8 seconds as TextField placeholder
- Tips include: "Ask anything...", "Try /compact to save context", "Attach images with the camera button", etc.
- Android: use `LaunchedEffect` with `delay(8000)` to cycle through tips, animate with `AnimatedContent` or `Crossfade`

### 2. History suggestions
- iOS shows recently used commands/messages as suggestion pills
- `MessageHistory` tracks per-session history
- Android: track recent inputs, show as horizontal pill row when input is focused but empty

### 3. @file search suggestions
- iOS supports `@filename` to search for and reference files
- Triggers file search via server, shows matching file paths as suggestions
- Android: detect `@` prefix in input, send search query, show results as pills

### 4. Voice input gesture refinement
- iOS uses swipe-up (>=60pt) to start recording, swipe-left to cancel
- Android currently uses tap-to-toggle
- Consider: long-press to record (release to send), or keep tap-to-toggle as Android convention

## Implementation notes
Sub-features 1-2 are InputBar-only changes. Sub-feature 3 requires server communication. Sub-feature 4 is a UX decision.

**Files (iOS reference):** GlobalInputBar+Suggestions.swift, GlobalInputBar+SuggestionPills.swift, GlobalInputBar+Recording.swift
**Files (Android):** InputBar.kt, ChatViewModel.kt
