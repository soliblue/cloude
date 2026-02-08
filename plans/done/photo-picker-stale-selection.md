# Photo Picker Stale Selection Bug
<!-- priority: 10 -->
<!-- tags: input -->
<!-- build: 56 -->

## Problem
When attaching a photo via the picker, removing it, then picking another photo — the first photo gets re-attached instead of the new one. The `selectedItem` state variable was never reset to `nil` after processing, so SwiftUI's `.onChange` either didn't fire (same item) or compared against stale state.

## Fix
- Reset `selectedItem = nil` after loading the image data
- Guard against nil to skip the reset itself from triggering work

## Files Changed
- `Cloude/Cloude/UI/GlobalInputBar.swift` — `.onChange(of: selectedItem)` handler
