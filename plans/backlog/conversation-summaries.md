# Conversation Summaries

## Summary
Generate concise summaries of conversations — either when they end (agent goes idle after significant work) or periodically. Store these summaries alongside the conversation for later use.

## Why
Conversations contain valuable context that gets lost after the session ends. Summaries could:
- Help users quickly scan what happened in old conversations
- Feed into the reflect skill for better memory updates
- Provide context when resuming conversations
- Show in the conversation list / window edit sheet

## Ideas
- **When to summarize**: After agent goes idle and conversation has 5+ messages
- **Where to store**: New field on Conversation model (`summary: String?`)
- **How to generate**: Background Haiku call (cheap, fast) with all messages as context
- **Display**: Show in WindowEditSheet conversation list, heartbeat overview

## Open Questions
- Should summaries update as conversations grow, or just once at "end"?
- How to detect "conversation end" vs just a pause?
- Should summaries be visible in the chat UI or just in the conversation picker?
