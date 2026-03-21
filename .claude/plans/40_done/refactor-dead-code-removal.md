# Dead Code Removal {trash}
<!-- priority: 10 -->
<!-- tags: refactor -->
<!-- build: 56 -->

> Removed unused methods and exposed internal properties to simplify the codebase.

## Changes
- Removed `GlobalInputBar.configureEffort(from:)` - unused method
- Removed `QuestionJSON.AnyCodable.~=` operator - unused pattern matching
- Changed `ToolCallLabel.iconNameForDetail` to expose `iconName` directly

## Test
- Effort level selection in send button menu still works
- Tool pills display correct icons in chat
- Tool detail sheet shows correct icons when tapping pills
