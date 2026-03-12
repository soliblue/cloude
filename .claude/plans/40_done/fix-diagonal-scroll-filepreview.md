# Fix Diagonal Scrolling in File Preview

## Problem
Text-based file previews (code, markdown source, etc.) allowed diagonal scrolling when both axes were enabled via `ScrollView([.vertical, .horizontal])`. This is confusing - you should scroll one axis at a time.

## Solution
Nested `ScrollView(.vertical)` containing `ScrollView(.horizontal)` so iOS locks to one axis per gesture. The inner horizontal scroll is disabled when `wrapCodeLines` is true (no horizontal scrolling needed).

## File Changed
- `FilePreviewView+Content.swift` - `sourceTextView` method
