---
title: "Chunk Progress for File Path Preview"
description: "Added chunk download progress bar to FilePathPreviewView for large files by porting Combine event subscription from FilePreviewView."
created_at: 2026-02-09
tags: ["file-preview", "ui"]
icon: arrow.down.circle
build: 69
---


# Chunk Progress for File Path Preview
`FilePathPreviewView` (chat file pill path) doesn't show chunk download progress for large files. It uses `connection.onFileContent` callback which only fires when all chunks are assembled.

`FilePreviewView` (FileBrowser path) already works — it subscribes to `connection.events` and listens for `.fileChunk` events to show a progress bar.

## Fix

Port the Combine-based event subscription from `FilePreviewView+Loading.swift` into `FilePathPreviewView+Content.swift:loadFile()`. Subscribe to `.fileChunk` events and show a linear progress bar with "X of Y" text during loading.

**Files:** `FilePathPreviewView.swift`, `FilePathPreviewView+Content.swift`
