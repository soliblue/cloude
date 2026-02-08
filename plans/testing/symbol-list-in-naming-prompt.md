# Symbol List in Naming Prompt

## Problem
The auto-naming prompt tells Sonnet to "pick a valid SF Symbol" but doesn't provide any list — Sonnet guesses from training data, leading to invalid symbol names that fall back to `bubble.left`.

## Solution
Include the curated symbol list from `SymbolPickerSheet` (deduplicated, ~250 unique symbols) in the `AutocompleteService.suggestName` prompt so Sonnet picks from known-valid symbols only.

## Files
- `Cloude Agent/Services/AutocompleteService.swift` — update prompt with symbol list
