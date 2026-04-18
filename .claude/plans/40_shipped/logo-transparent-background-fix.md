# Logo Transparent Background Fix {photo}
<!-- priority: 10 -->
<!-- tags: ui, header -->
<!-- build: 77 -->

> Fixed logo toolbar tint by adding .renderingMode(.original) to prevent template rendering.

## Changes
- Added `.renderingMode(.original)` to the logo `Image` in `CloudeApp+StatusLogo.swift`
- This tells iOS to render the image as-is instead of treating it as a template image

## Test
- Logo should appear without any background tint/highlight in the toolbar
