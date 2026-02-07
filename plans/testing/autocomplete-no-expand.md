# Autocomplete Suggestions Should Not Expand Input Field

## Problem

When Haiku returns a multi-line autocomplete suggestion, the input bar grows to accommodate it. For example, a 2-line suggestion makes the input field become 2 lines tall. The input field should stay at its default single-line height regardless of suggestion length.

## Root Cause

In `GlobalInputBar.swift`, both the suggestion overlay and the TextField share the same `.lineLimit(1...4)`:

```swift
// Suggestion layer
Text(inputText + autocompleteSuggestion)
    .lineLimit(1...4)

// Input field
TextField("", text: $inputText, axis: .vertical)
    .lineLimit(1...4)
```

The suggestion text expands vertically, which pushes the container (and thus the input field) to grow.

## Fix

Clamp the suggestion text to a single line so it doesn't affect the container height:

- Change the suggestion `Text` to `.lineLimit(1)` with `.truncationMode(.tail)`
- The actual TextField should still expand based on **user-typed text** (1...4 lines) — just not because of the grayed-out suggestion

This way:
- User types 1 line → input is 1 line, suggestion is 1 line (truncated if longer)
- User types 3 lines → input is 3 lines, suggestion still only shows line 1 of the completion
- Suggestion never drives the height, only user input does

## Files

- `Cloude/Cloude/UI/GlobalInputBar.swift` (~line 283)
