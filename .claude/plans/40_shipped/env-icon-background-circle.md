# Environment Icon Background Circle {circle.dashed}
<!-- priority: 10 -->
<!-- tags: ui, header, env -->

> Added subtle circular background behind environment icon in window header.

Add a subtle circular background behind the environment icon in the window header for better visual distinction.

## Changes
- `MainChatView+Windows.swift`: Added 28pt circle with `secondary.opacity(0.12)` background behind env symbol, slightly reduced icon size to 12pt semibold
