---
title: "Git Refresh on Tab Switch & History Auto-Send"
description: "Refresh git status when switching windows and auto-send when selecting a history suggestion."
created_at: 2026-04-02
tags: ["ui", "git"]
icon: arrow.triangle.2.circlepath
build: 122
---


# Git Refresh on Tab Switch & History Auto-Send {arrow.triangle.2.circlepath}
## Changes

- `WorkspaceStore+Lifecycle`: trigger `gitStatus` on active window change so the git tab is fresh
- `WorkspaceView+InputBar+Content`: selecting a history suggestion now dismisses keyboard and sends immediately
- `WorkspaceView`: pass connection to `handleActiveWindowChange`
