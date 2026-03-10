# Conversation Export

Add an export button to the right side of the window header. Copies the full conversation to clipboard (or shares it).

## Use Cases
- Copy conversation to paste into docs, notes, or share with someone
- Save a useful conversation for reference
- Export to markdown for blog posts or documentation

## UX
- Tap export button (square.and.arrow.up) in the header
- Options: copy to clipboard, share sheet, or both
- Format as clean markdown: user messages, assistant messages, tool calls summarized
- Could also support: copy last message only, copy code blocks only

## Format
```markdown
**User**: How do I fix the login bug?

**Claude**: The issue is in AuthManager.swift...

**Tool**: Read /path/to/file.swift

**Claude**: Here's the fix...
```

## Header placement
4th button on the right side, next to fork/refresh/close. Balances the 4 left-side tabs (chat, files, git, terminal).

## File
- `Cloude/UI/MainChatView+Windows.swift` - add export button to right-side HStack
- New helper to format conversation as markdown
