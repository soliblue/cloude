---
title: "Show Dotfiles in File Browser"
description: "Show dotfiles (.env, .claude, .gitignore) in the file browser by removing the skipsHiddenFiles option."
created_at: 2026-03-14
tags: ["file-preview", "agent"]
icon: eye
build: 86
---


# Show Dotfiles in File Browser {eye}
## Change
Removed `.skipsHiddenFiles` option from `FileService.listDirectory` so dotfiles (`.env`, `.claude`, `.gitignore`, etc.) appear in the file browser tab.

## File Changed
- `Cloude Agent/Services/FileManager.swift` - line 19: `options: [.skipsHiddenFiles]` → `options: []`

## Status
Needs agent rebuild to take effect.
