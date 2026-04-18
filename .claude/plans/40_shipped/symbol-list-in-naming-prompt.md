---
title: "Symbol List in Naming Prompt"
description: "Included curated SF Symbol list in the auto-naming prompt so Sonnet picks valid symbols instead of guessing."
created_at: 2026-02-08
tags: ["agent"]
icon: list.bullet
build: 67
---


# Symbol List in Naming Prompt {list.bullet}
## Problem
The auto-naming prompt tells Sonnet to "pick a valid SF Symbol" but doesn't provide any list — Sonnet guesses from training data, leading to invalid symbol names that fall back to `bubble.left`.

## Solution
Include the curated symbol list from `SymbolPickerSheet` (deduplicated, ~250 unique symbols) in the `AutocompleteService.suggestName` prompt so Sonnet picks from known-valid symbols only.

## Files
- `Cloude Agent/Services/AutocompleteService.swift` — update prompt with symbol list
