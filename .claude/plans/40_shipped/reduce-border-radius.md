---
title: "Reduce Border Radius ~25%"
description: "Reduced all cornerRadius values by ~25% and converted circular buttons to rounded rectangles."
created_at: 2026-03-01
tags: ["ui", "theme"]
icon: square
build: 82
---


# Reduce Border Radius ~25% {square}
## Summary
Reduced all cornerRadius values across the app by ~25% for a tighter, more angular look. Also converted circular buttons (send, scroll-to-bottom, connection status) to rounded rectangles for consistency.

## Mapping
22→16, 20→15, 14→10, 12→9, 11→8, 10→8, 8→6, 6→4, 4→3, 3→2

## Buttons
- Send button: Circle → RoundedRectangle(cornerRadius: 10)
- Scroll-to-bottom: Circle → RoundedRectangle(cornerRadius: 10)
- Connection status icon: Circle → RoundedRectangle(cornerRadius: 10)

## Files
26 UI files modified
