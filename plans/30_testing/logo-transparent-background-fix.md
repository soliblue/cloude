# Logo Transparent Background Fix

Fix the logo in the top-left toolbar having an iOS-applied tinted background.

## Changes
- Added `.renderingMode(.original)` to the logo `Image` in `CloudeApp+StatusLogo.swift`
- This tells iOS to render the image as-is instead of treating it as a template image

## Test
- Logo should appear without any background tint/highlight in the toolbar
