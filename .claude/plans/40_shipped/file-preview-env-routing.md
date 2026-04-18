---
title: "File Preview Environment Routing"
description: "Fixed file preview sending get_file to wrong relay when multiple environments are connected."
created_at: 2026-03-10
tags: ["file-preview", "env"]
icon: doc.viewfinder
build: 82
---


# File Preview Environment Routing {doc.viewfinder}
## Problem

After the multi-env refactor, tapping a file path pill in chat sends the `get_file` request to whichever relay authenticated first (`anyAuthenticatedConnection`), not the relay where the file exists. This causes ENOENT errors when connected to both Mac and Linux relays.

## Fix

- `FilePreviewView` accepts optional `environmentId` parameter
- `CloudeApp.swift` passes `currentConversation.environmentId` when opening file preview from pill tap or plans sheet
- `loadFile()`, `loadFullQuality()`, `loadGitDiff()` all forward `environmentId` to ConnectionManager API calls

## Files Changed

- `Cloude/Cloude/UI/FilePreviewView.swift`
- `Cloude/Cloude/UI/FilePreviewView+Loading.swift`
- `Cloude/Cloude/App/CloudeApp.swift`
