---
name: email
description: Read, search, and compose emails via Apple Mail. Real-time access via AppleScript — no API keys, no OAuth, no dependencies.
user-invocable: true
icon: envelope
aliases: [mail, inbox]
---

# Apple Mail Skill

Real-time access to Mail.app via AppleScript. Works with any email account configured in Mail.app (Gmail, iCloud, Outlook, etc.).

## First-Time Setup

Run any script once from Terminal to trigger the macOS permission dialog:
```bash
bash .claude/skills/email/mail-accounts.sh
```
Click "Allow" in System Settings → Privacy & Security → Automation → Terminal → Mail.

## Scripts

### List accounts
```bash
bash .claude/skills/email/mail-accounts.sh
```

### Check inbox (unread)
```bash
bash .claude/skills/email/mail-inbox.sh              # 10 most recent unread
bash .claude/skills/email/mail-inbox.sh 25             # 25 most recent unread
bash .claude/skills/email/mail-inbox.sh 10 "Gmail"     # Unread from specific account
```

### Read full email
```bash
bash .claude/skills/email/mail-read.sh <message_id>
```
Use the ID from mail-inbox.sh or mail-search.sh output.

### Search emails
```bash
bash .claude/skills/email/mail-search.sh "knowunity"           # Search subject + sender
bash .claude/skills/email/mail-search.sh "invoice" 50           # Search with limit
bash .claude/skills/email/mail-search.sh "mom" 10 "Gmail"       # Search specific account
```

### Compose email
```bash
bash .claude/skills/email/mail-send.sh "to@example.com" "Subject" "Body text"
```
**IMPORTANT**: This opens the email in Mail.app as a draft. It does NOT auto-send.
The user must review and click Send manually, or explicitly ask Cloude to send.

## Output Format

Inbox/search results are pipe-separated:
```
ID|From|Subject|Date|Read|Account
```

Full email read returns:
```
From: sender@example.com
To: recipient@example.com
Subject: The subject
Date: 2026-02-14
---
Email body text here...
```

## Security

**This skill is deliberately cautious:**
- Reading emails: runs freely
- Composing: creates a DRAFT by default, does not send
- Sending: only when user explicitly says "send it" — never auto-send
- No email content is stored, cached, or written to disk
- No forwarding without explicit confirmation
- Email bodies may contain sensitive data — never include full bodies in logs or memory files
- Summarize content, don't quote it verbatim (unless user asks)
