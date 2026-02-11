# Reading Progress Indicator

## What
Vertical dot indicator on the right edge of long assistant messages showing scroll position within the message.

## Design
- 5 small dots, vertically centered on the right edge of the message
- Dots fill/highlight as you scroll through the message
- Only appears on messages taller than the viewport
- Subtle glass material, doesn't interfere with content
- Tappable dots to jump to that section of the message

## Implementation
- Named coordinate space on ScrollView for position tracking
- GeometryReader on each assistant message to track frame vs viewport
- Progress calculated as: (viewportCenter - messageTop) / messageHeight
- Active dot = floor(progress * 5)
- New file: ReadingProgressView.swift
- Overlay on MessageBubble trailing edge

## Status
Active — implementing now
