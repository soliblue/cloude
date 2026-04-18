---
title: "Android Working Directory Picker"
description: "Let users select the working directory per conversation before sending the first message."
created_at: 2026-03-28
tags: ["android", "chat", "input"]
build: 120
icon: folder.badge.gearshape
---
# Android Working Directory Picker {folder.badge.gearshape}


## Desired Outcome
Folder picker in the chat empty state. Shows current working directory path with a tap-to-change button. Opens a directory-only browser as a sheet. Directory stored per conversation, only editable before first message (sessionId == nil). Header shows last path component.

**Files (iOS reference):** EnvironmentFolderPicker.swift, FolderPickerView.swift
**Files (Android):** ChatScreen.kt (empty state), Conversation.kt (workingDirectory field), FileBrowserScreen.kt (reuse for directory picking)
