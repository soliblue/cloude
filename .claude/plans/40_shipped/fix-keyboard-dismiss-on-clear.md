---
title: "Fix Keyboard Dismissing When Clearing Input Bar"
description: "Fixed keyboard dismissing when clearing input bar by using stable TextField identity."
created_at: 2026-03-13
tags: ["ui", "input"]
icon: keyboard
build: 86
---


# Fix Keyboard Dismissing When Clearing Input Bar {keyboard}
Clearing all text in the global input bar dismissed the keyboard, forcing users to tap the field again to keep typing.

## Root Cause
`textFieldId = UUID()` in `GlobalInputBar.swift` was called every time `inputText` went from non-empty to empty. This recreated the TextField with a new identity, destroying focus and dismissing the keyboard.

## Fix
- Removed dynamic `textFieldId` state variable
- Gave TextField a stable `.id("inputField")` instead
- Placeholder rotation still works via `placeholderIndex` change

**Files:** `GlobalInputBar.swift`
