---
title: "Remove \"No Changes\" Empty State from Git View"
description: "Removed redundant \"No Changes\" placeholder from git view since header already shows 0 count."
created_at: 2026-03-15
tags: ["ui", "git"]
icon: xmark.circle
build: 86
---


# Remove "No Changes" Empty State from Git View {xmark.circle}
Removed the ContentUnavailableView("No Changes") from GitChangesView. The branch header already shows 0 file count, which is sufficient.

## Test
- Open git tab with a clean working tree
- Should show empty list, no "No Changes" placeholder
- Header still shows branch name + 0 count
