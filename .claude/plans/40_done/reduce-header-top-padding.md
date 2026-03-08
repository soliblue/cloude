# Reduce Header Top Padding
<!-- build: 82 -->

Removed the 7pt top padding from window headers (both regular and heartbeat) to tighten the gap between the iOS navigation bar and the window header. Bottom padding preserved at 7pt.

## Changes
- `MainChatView+Windows.swift`: `.padding(.vertical, 7)` → `.padding(.top, 0)` + `.padding(.bottom, 7)`
- `MainChatView+Heartbeat.swift`: same change
