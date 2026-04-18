---
title: "Copy Button on Assistant Messages"
description: "Added inline copy button to assistant message bubble footer next to the refresh button."
created_at: 2026-02-08
tags: ["ui"]
icon: doc.on.doc
build: 67
---


# Copy Button on Assistant Messages {doc.on.doc}
**Status**: Testing
**Created**: 2026-02-08

## What
Add an inline copy button to the left of the refresh button on every assistant message bubble footer.

## Changes
- `ChatView+MessageBubble.swift`: Added `doc.on.doc` copy button before the refresh button in the assistant message HStack. Reuses existing `showCopiedToast` state and toast overlay.
