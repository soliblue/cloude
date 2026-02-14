---
name: imessage
description: Read and send iMessages. Read via SQLite (chat.db), send via AppleScript. Works with iMessage and SMS.
user-invocable: true
icon: message.fill
aliases: [messages, sms, text, imsg]
---

# iMessage Skill

Read iMessage/SMS conversations from the local SQLite database and send messages via AppleScript. No API keys, no dependencies.

## First-Time Setup

Grant Full Disk Access to read the message database:
System Settings → Privacy & Security → Full Disk Access → enable for Terminal (and Cloude Agent).

Sending messages requires Automation permission for Messages.app (prompted on first send).

## Scripts

### List recent conversations
```bash
bash .claude/skills/imessage/msg-chats.sh              # 20 most recent chats
bash .claude/skills/imessage/msg-chats.sh 50            # 50 most recent
```

### Read messages from a contact
```bash
bash .claude/skills/imessage/msg-read.sh "+1-555-000-0000"       # By phone number
bash .claude/skills/imessage/msg-read.sh "email@icloud.com"      # By email
bash .claude/skills/imessage/msg-read.sh "+1-555-000-0000" 50    # Last 50 messages
```

### Search messages
```bash
bash .claude/skills/imessage/msg-search.sh "dinner"              # Search all chats
bash .claude/skills/imessage/msg-search.sh "airport" 30          # With result limit
```

### Send a message
```bash
bash .claude/skills/imessage/msg-send.sh "+1-555-000-0000" "Hey, running 10 min late"
bash .claude/skills/imessage/msg-send.sh "email@icloud.com" "Got it, thanks!"
```
**IMPORTANT**: Sends immediately via Messages.app. Always confirm with user before executing.

## Output Format

Chats list:
```
ChatID|Contact|LastMessage|Date
```

Messages:
```
Date|From|Text
```

## Security
- Reading: Full Disk Access permission required (reads ~/Library/Messages/chat.db)
- Sending: always confirm with user before executing — never auto-send
- Message content is sensitive — summarize, don't quote verbatim in logs or memory
- No message data is cached or written to disk by these scripts
- Database is read-only — scripts never modify chat.db

## Technical Notes
- macOS Ventura+ stores some messages in `attributedBody` blob instead of `text` column
- The read script decodes both formats automatically
- Date math: iMessage timestamps are nanoseconds since 2001-01-01 (Apple epoch)
- Group chats use `cache_roomnames` for identification
