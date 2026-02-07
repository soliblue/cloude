# Conversation Summaries

After conversations end, the context is lost. No quick way to scan what happened in old conversations or provide context when resuming.

## Desired Outcome
Auto-generate concise summaries (background Haiku call) after agent goes idle on conversations with 5+ messages. Store on the Conversation model, display in conversation list and window edit sheet. Feeds into reflect skill.

**Files:** `Conversation.swift`, new summary generation service, conversation list UI
