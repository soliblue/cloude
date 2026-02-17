# Conversation Limit Recovery

## Problem
When a conversation hits its cost limit, there's no way to recover or continue it. The conversation is effectively dead — user has to start a new one and lose context.

## Desired Behavior
- Allow resuming a conversation that hit its limit (e.g., raise/remove the limit)
- Or provide a way to fork/continue the conversation in a new session while preserving context
- Clear UX in the cost banner or conversation UI to take action

## Notes
- Cost banner already shows when limit is reached (`CostBanner` in `ConversationView+Components.swift`)
- Need to decide: raise limit vs reset vs fork
