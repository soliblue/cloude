# Remove Collapsible Markdown Headers

Removed the collapsible/expandable header sections from StreamingMarkdownView. Headers now render as plain blocks with no chevrons, no collapse state, and no tree structure.

## Changes
- Deleted StreamingMarkdownView+ContentTree.swift
- Simplified StreamingMarkdownView.swift to render blocks flat
- Removed collapsedHeaders state and toggleCollapse logic

## Testing
- [ ] Long messages with headers render correctly
- [ ] Streaming messages with headers render smoothly
- [ ] Completed messages with headers look correct
