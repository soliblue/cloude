# Dead Code Cleanup Round 3

Removed unused code across multiple UI files:

- MessageBubble: removed unused CopiedToast view, InterleavedMessageContent wrapper (was just forwarding to StreamingMarkdownView), unused isMarkdown param from TextSelectionSheet
- ConversationView+Components: removed unused scrollToMessage method
- ToolCallLabel: removed "claude" case from bash command label (no longer needed)
- UsageStatsSheet: removed unused shortDate helper
