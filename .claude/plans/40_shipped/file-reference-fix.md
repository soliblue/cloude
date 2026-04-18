---
title: "File Reference Fix (@mention)"
description: "Fixed file @mention inserting filename instead of full path and suggestions disappearing on dot."
created_at: 2026-03-10
tags: ["input"]
icon: at
build: 82
---


# File Reference Fix (@mention) {at}
Fixed two issues preventing file references from working in the input bar:

1. **`selectFile`** inserted only the filename (`CLAUDE.md`) instead of the full path - Claude Code needs the full path to reference files
2. **`atMentionQuery`** had a `hasExtension` check that hid suggestions as soon as the user typed a dot (e.g. `@CLAUDE.m` killed suggestions)

**Files changed:** `Cloude/Cloude/UI/GlobalInputBar.swift`
