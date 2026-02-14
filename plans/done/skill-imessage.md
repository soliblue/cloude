# iMessage Skill {message.fill}
<!-- priority: 7 -->
<!-- tags: skill, integration, communication -->

> Read and send iMessages via SQLite (chat.db) + AppleScript. Handles macOS Ventura+ attributedBody decoding via Python. No dependencies beyond system Python.

## Architecture
- **Read**: Python script reads `~/Library/Messages/chat.db` directly, decodes both `text` and `attributedBody` formats
- **Send**: AppleScript via `osascript` to Messages.app
- **Search**: SQL LIKE queries on message text

## Permissions Needed
- Full Disk Access (for reading chat.db)
- Automation → Messages.app (for sending, prompted on first use)

## Security
- Sends only with explicit user confirmation — never auto-send
- Database is read-only, scripts never modify chat.db
- Message content treated as sensitive — summarize, don't quote in logs

## Status
- Scripts built, not yet tested (permissions needed)

**Files:** `.claude/skills/imessage/`
