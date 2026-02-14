# Email Skill {envelope}
<!-- priority: 8 -->
<!-- tags: skill, integration, communication -->

> Read, compose, reply, search, and organize emails. Support Gmail (primary) via IMAP/SMTP or Google API. Inspired by OpenClaw's himalaya integration.

## Approach
Two options (decide during implementation):
1. **himalaya CLI** — Rust-based email client, install via brew, supports IMAP/SMTP with app passwords. Zero code needed, just shell wrappers.
2. **Google API + OAuth** — More setup but richer (labels, threads, real-time push). Needs OAuth token flow.

Start with himalaya (simpler), upgrade to Google API if needed.

## Commands
- List inbox (unread count, recent messages)
- Read email by ID (full body)
- Compose and send email
- Reply / forward
- Search by sender, subject, date, keyword
- Move to folder / archive / delete
- List folders/labels

## Use Cases
- "Any new emails?"
- "Reply to the email from Mom"
- "Send an email to X about Y"
- Heartbeat: check inbox, summarize unread, flag urgent

## Security
- App password stored in Keychain (not .env)
- Sender allowlist for auto-replies (ties into external-comms-autonomy plan)
- Confirmation required before sending (unless explicitly autonomous)

**Files:** `.claude/skills/email/`, himalaya config or Google OAuth setup
