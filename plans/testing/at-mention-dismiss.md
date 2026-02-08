# Fix: @ autocomplete doesn't dismiss after space

## Problem
File suggestions from `@` autocomplete stayed visible even after typing a space and continuing to type. E.g., `@ajsifb wjdj` would still show suggestions.

## Fix
- `atMentionQuery` now returns `nil` as soon as any whitespace appears after the `@` word
- `selectFile` simplified — appends filename + space, no need to preserve text after the mention since suggestions are only active mid-word
- Files: `GlobalInputBar.swift`
