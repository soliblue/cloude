---
title: "Drop dead protocol cases across all layers"
description: "Remove killAllProcesses, listRemoteSessions, remoteSessionList, fileChange, image, and query from fileSearchResults across Swift, Kotlin, and Node.js."
created_at: 2026-04-18
tags: ["agent", "streaming"]
icon: trash
---

# Drop dead protocol cases across all layers

Removed unused message types and fields that had no live callers:

- `ClientMessage.killAllProcesses` / `kill_all_processes`
- `ClientMessage.listRemoteSessions` / `list_remote_sessions`
- `ServerMessage.remoteSessionList` / `remote_session_list`
- `ServerMessage.fileChange` / `file_change`
- `ServerMessage.image` / `image`
- `query` field on `fileSearchResults` (never read by any handler)
- `RemoteSession` model (Swift + Kotlin)

Cleanup applied consistently in CloudeShared, macOS agent, iOS app, Android models, and linux-relay.
