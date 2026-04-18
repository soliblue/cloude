---
title: "Dead Code Cleanup Round 3"
description: "Removed unused views, methods, and parameters across MessageBubble, ConversationView, ToolCallLabel, and UsageStatsSheet."
created_at: 2026-03-15
tags: ["refactor"]
icon: trash
build: 86
---


# Dead Code Cleanup Round 3 {trash}
Removed unused code across multiple UI files:

- MessageBubble: removed unused CopiedToast view, InterleavedMessageContent wrapper (was just forwarding to StreamingMarkdownView), unused isMarkdown param from TextSelectionSheet
- ConversationView+Components: removed unused scrollToMessage method
- ToolCallLabel: removed "claude" case from bash command label (no longer needed)
- UsageStatsSheet: removed unused shortDate helper
