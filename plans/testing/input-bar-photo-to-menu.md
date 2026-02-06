# Move Photo Button to Send Menu

## Summary
Moved the image picker button from a standalone button on the left side of the input bar into the send button's long-press menu, alongside Record and Effort options.

## Changes
- Removed `PhotosPicker` button from left side of input bar HStack
- Added "Photo" option as first item in send button's long-press `Menu`
- Uses `showPhotoPicker` state + `.photosPicker()` modifier instead of inline `PhotosPicker` view
- Removed `.disabled()` on Menu so photo picker is always accessible
- More horizontal space for the text field

## Files
- `Cloude/Cloude/UI/GlobalInputBar.swift`

## Test
- Long press send button → menu shows Photo, Record, Effort
- Tap Photo → system photo picker opens
- Select image → thumbnail appears in text field
- Tap send with image attached → sends correctly
- Swipe up to record still works
- Effort level selection still works
