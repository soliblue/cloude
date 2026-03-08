# Text Selection & Partial Copy

Long press any message to open text in a selectable sheet (ChatGPT-style).

## Changes
1. Long press on any message (user or assistant) opens `TextSelectionSheet`
2. Sheet has selectable `UITextView` with link detection + copy-all button
3. Clear overlay on `Group` captures long press above `StreamingMarkdownView`
4. Removed inline `SelectableTextView` from user messages (caused scroll lock crashes)
5. `SelectableTextView` kept only for inline link/file pill rendering
