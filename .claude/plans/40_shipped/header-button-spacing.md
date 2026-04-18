---
title: "Header Button Spacing Fix"
description: "Removed extra spacing between right-side header buttons to match the left-side tab buttons."
created_at: 2026-03-10
tags: ["ui", "header"]
icon: arrow.left.and.right
build: 82
---


# Header Button Spacing Fix {arrow.left.and.right}
## Problem

Left-side tabs (chat, files, git) use `spacing: 0` with thin dividers - tight and clean.
Right-side buttons (fork, refresh, close) have dividers between them but sit inside the outer `HStack(spacing: 9)`, adding extra spacing that the left side doesn't have.

## Fix

Wrap right-side buttons in their own `HStack(spacing: 0)` (like the left tabs), so dividers are the only spacing. Both sides match.

## File
- `Cloude/UI/MainChatView+Windows.swift` - `windowHeader` function
