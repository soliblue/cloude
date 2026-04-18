---
title: "Logo Transparent Background Fix"
description: "Fixed logo toolbar tint by adding .renderingMode(.original) to prevent template rendering."
created_at: 2026-03-01
tags: ["ui", "header"]
icon: photo
build: 76
---


# Logo Transparent Background Fix {photo}
## Changes
- Added `.renderingMode(.original)` to the logo `Image` in `CloudeApp+StatusLogo.swift`
- This tells iOS to render the image as-is instead of treating it as a template image

## Test
- Logo should appear without any background tint/highlight in the toolbar
