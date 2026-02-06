# Conversation Cost Tracking

Show running cost per conversation. We already get `costUsd` per message from Claude CLI — just need to sum and display it.

## Goals
- Users can see how much a conversation has cost so far
- Quick gut check before continuing expensive sessions

## Approach
- Sum `costUsd` across all messages in a conversation
- Display in conversation header, info sheet, or conversation picker
- Update live during streaming as new cost data arrives

## Files
- `Cloude/Cloude/Models/Conversation.swift` — computed property for total cost
- `Cloude/Cloude/UI/ChatView.swift` or header — display cost
- Possibly `Cloude/Cloude/UI/ConversationPicker` — show cost per conversation in list

## Notes
- `costUsd` comes from the CLI stream and is the most reliable signal we have
- No tokenizer needed — just dollar amounts
- Keep formatting simple: "$0.42" or "$3.17"
- Small feature, big awareness
