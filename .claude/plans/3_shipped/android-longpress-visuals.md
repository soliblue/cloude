---
title: "Android Long-Press Visual Polish"
description: "Improve ripple/highlight feedback on long-press for assistant message bubbles."
created_at: 2026-04-05
tags: ["android", "ui", "polish"]
build: 125
icon: hand.tap
---
# Android Long-Press Visual Polish


## Current State
Long-press on assistant messages works functionally (context menu appears) but the ripple animation differs from user messages:
- User messages: `combinedClickable` provides native Material ripple that persists for the full touch duration automatically.
- Assistant messages: Uses programmatic `PressInteraction.Press/Release` via shared `MutableInteractionSource` between the Box and child `MarkdownText`. The ripple works but may feel slightly different because gesture handling lives inside each `Text` composable (Paragraph, ListItem) rather than on the parent container.

## Desired Outcome
- Ripple on assistant messages should feel identical to user messages (same hold duration, same visual weight).
- Consider using `Modifier.indication()` with a custom `Indication` that better matches the hold-to-reveal pattern.
- Explore whether a semi-transparent overlay (like iOS highlight) would feel more native than ripple for long-press context menus.

## Technical Notes
- Root cause: `MarkdownText` contains multiple `Text` composables with individual `pointerInput(detectTapGestures)` handlers. The `interactionSource` is shared up to the parent Box which has `Modifier.indication()`, but the press coordinates originate from child composables.
- `ClickableText` was removed because it consumed all touch events including long-press. The current `Text` + `pointerInput` approach is the correct architecture, just needs visual refinement.
- Relevant files: `MessageBubble.kt`, `MarkdownText.kt`

**Files (iOS reference):** MessageBubble.swift (uses `.contextMenu` which provides native highlight automatically)
