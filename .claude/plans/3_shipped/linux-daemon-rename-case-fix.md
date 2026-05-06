---
title: "Linux Daemon Conversation Rename Bug Fix"
description: "Fixed case-sensitivity bug in readTranscript on Linux causing rename to fail."
created_at: 2026-05-06
tags: ["daemon", "files"]
icon: filebadge.xmark
build: 155
---

# Linux Daemon Conversation Rename Bug Fix

Fixed case-sensitivity issue in the Linux daemon's SessionHandler where conversation rename always returned `transcript_not_found`.

## Root Cause

Swift's `UUID.uuidString` produces uppercase UUIDs (e.g., `A1B2C3D4-...`), but Claude Code stores transcript files with lowercase UUIDs (e.g., `a1b2c3d4-...`). macOS's case-insensitive filesystem (HFS+) masked this bug, but Linux's ext4 is case-sensitive, so the file lookup failed every time.

## Fix

Added `.toLowerCase()` when building the transcript file path in `readTranscript` to match the stored filename convention.

Also added error logging in `runSonnet` when the process fails, matching the macOS daemon's behavior for consistency.

## Files Changed

- `daemons/linux/src/Handlers/SessionHandler.js`
