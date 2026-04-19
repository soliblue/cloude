---
title: "Linux Relay Modular Refactor"
description: "Split monolithic handlers.js into domain-specific modules for maintainability."
created_at: 2026-03-10
tags: ["refactor", "relay"]
icon: wrench.and.screwdriver
build: 82
---


# Linux Relay Modular Refactor
## Changes

- Deleted dead `agent-linux/` directory
- Created `shared.js` with unified constants (`DEFAULT_PROJECT`, `extractToolInput`, `MIME_TYPES`, etc.)
- Split `handlers.js` (704 lines) into 5 domain files:
  - `handlers-files.js` - directory listing, file serving, search
  - `handlers-git.js` - git status, diff, commit
  - `handlers-history.js` - usage stats, remote sessions, history sync
  - `handlers-plans.js` - memories, plans
  - `handlers-naming.js` - conversation name suggestion
  - `handlers-terminal.js` - terminal exec, transcription
- `handlers.js` now just the router (~110 lines)
- Deduplicated `extractToolInput` (was in both `handlers.js` and `runner.js`)
- Added `skills.js` for loading skill definitions on auth (was missing from Linux agent)

## Zero behavior changes - pure structural refactor
