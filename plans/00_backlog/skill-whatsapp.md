# WhatsApp Skill {message}
<!-- priority: 6 -->
<!-- tags: skill, integration, communication -->

> Read and send WhatsApp messages. Uses Baileys (reverse-engineered WA Web protocol) or WhatsApp Business API. Most transformative communication integration.

## Approach
**Option A — Baileys (Node.js):** Open-source, no business account needed, full access to personal WhatsApp. Requires QR code pairing once. Used by OpenClaw. Risk: unofficial, Meta could break it.

**Option B — WhatsApp Business API:** Official, stable, but requires business account + phone number. Better for sending, limited for reading personal chats.

Start with Baileys for personal use.

## Commands
- List recent chats
- Read messages from a contact/group
- Send message to contact/group
- Search messages by keyword
- Send media (photos, voice notes)

## Use Cases
- "Any new WhatsApp messages?"
- "Send Mom a message saying I'll be late"
- "What did Adam say in our group?"
- Heartbeat: check unread, summarize important messages

## Security
- Sender allowlist for auto-replies
- Confirmation before sending (unless overridden)
- Session stored locally (no cloud)

## Complexity
Higher than Apple skills — needs Node.js runtime, QR auth flow, session persistence. Worth it for the value.

**Files:** `.claude/skills/whatsapp/`, Node.js Baileys wrapper
