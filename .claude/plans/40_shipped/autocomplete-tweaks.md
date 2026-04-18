---
title: "Autocomplete tweaks"
description: "Increased autocomplete trigger length to 90 chars and prevented ghost text from expanding the input bar."
created_at: 2026-02-07
tags: ["input"]
icon: text.cursor
build: 43
---


# Autocomplete tweaks {text.cursor}
## Changes
- Max input length for autocomplete trigger: 30 → 90 characters
- Ghost text overlay no longer expands the input bar — uses `fixedSize(horizontal: false, vertical: false)` to stay within the TextField's bounds, truncates with `...` if too long
- Debounce was already 500ms (no change needed)
