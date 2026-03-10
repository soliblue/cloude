# Header Button Spacing Fix

Remove extra spacing between right-side header buttons to match the left-side tab buttons.

## Problem

Left-side tabs (chat, files, git) use `spacing: 0` with thin dividers - tight and clean.
Right-side buttons (fork, refresh, close) have dividers between them but sit inside the outer `HStack(spacing: 9)`, adding extra spacing that the left side doesn't have.

## Fix

Wrap right-side buttons in their own `HStack(spacing: 0)` (like the left tabs), so dividers are the only spacing. Both sides match.

## File
- `Cloude/UI/MainChatView+Windows.swift` - `windowHeader` function
