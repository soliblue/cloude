---
title: "Git tab tree view toggle"
description: "VS Code style tree view for changes list with single-child folder compaction."
created_at: 2026-06-12
tags: ["ui"]
icon: tree
build: 155
---

# Git tab tree view toggle

Flat list vs folder tree view in the iOS git tab. Folders expanded by default with single-child folder compaction (VS Code style). Toggle button in the git status header, persisted via AppStorage.

Tree building compacts single-child intermediate folders into dotted paths (e.g., `src/components/ui` instead of nested folders). Collapsed state tracked separately for staged and unstaged sections.
