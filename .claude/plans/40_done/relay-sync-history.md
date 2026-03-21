# Relay Sync History {arrow.clockwise.icloud}
<!-- priority: 10 -->
<!-- tags: relay -->

> Implemented sync_history in the Linux relay to parse JSONL session files for the iOS refresh button.

Implement `sync_history` in the Linux relay so the refresh button works. Parses Claude Code JSONL session files and sends messages back in the format the iOS app expects, with Apple reference date timestamps.
