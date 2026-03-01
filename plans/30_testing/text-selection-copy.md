# Text Selection & Partial Copy

Enable selecting and copying parts of message text instead of all-or-nothing.

## Problem
- `.contextMenu` on MessageBubble intercepts long-press, blocking iOS text selection
- User messages don't have `.textSelection(.enabled)` at all
- Context menu is redundant (copy/collapse/TTS buttons exist in toolbar)

## Changes
1. Remove `.contextMenu` from MessageBubble — unblocks text selection gesture
2. Add `.textSelection(.enabled)` to user message `Text` view
3. Keep existing copy button for full-message copy
