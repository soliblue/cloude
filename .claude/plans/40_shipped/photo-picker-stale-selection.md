---
title: "Photo Picker Stale Selection Bug"
description: "Fixed stale photo selection bug where removing and re-picking a photo would re-attach the old one."
created_at: 2026-02-07
tags: ["input"]
icon: photo.badge.exclamationmark
build: 43
---


# Photo Picker Stale Selection Bug {photo.badge.exclamationmark}
## Problem
When attaching a photo via the picker, removing it, then picking another photo — the first photo gets re-attached instead of the new one. The `selectedItem` state variable was never reset to `nil` after processing, so SwiftUI's `.onChange` either didn't fire (same item) or compared against stale state.

## Fix
- Reset `selectedItem = nil` after loading the image data
- Guard against nil to skip the reset itself from triggering work

## Files Changed
- `Cloude/Cloude/UI/GlobalInputBar.swift` — `.onChange(of: selectedItem)` handler
