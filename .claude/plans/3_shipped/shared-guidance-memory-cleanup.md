---
title: "Shared Guidance Memory Cleanup"
description: "Keep shared project guidance public and leave personal memory files ignored."
created_at: 2026-05-10
updated_at: 2026-05-10
tags: ["settings"]
icon: doc.text
---

# Shared Guidance Memory Cleanup

## Implementation

`CLAUDE.md` now describes shared project knowledge as the place for concise collaborator-facing guidance. Personal `.claude/memory` content stays ignored without assuming a directory-only path, and `.claude/settings.json` declares `.claude/plans` as the plans directory.

## Verify

- Confirm `.claude/settings.json` points `plansDirectory` at `.claude/plans`.
- Confirm `.claude/memory` is ignored whether it is a symlink or directory.
- Confirm the shared guidance no longer asks agents to write personal memory details into public docs.
