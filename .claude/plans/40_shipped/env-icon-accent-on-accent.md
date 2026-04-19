---
title: "Fix env icon accent-on-accent color in window header"
description: "Fixed low-contrast accent-on-accent environment icon in window header by using white symbol on accent background."
created_at: 2026-03-16
tags: ["ui", "header", "env"]
icon: circle.fill
build: 86
---


# Fix env icon accent-on-accent color in window header
The environment icon shown in the middle of the window header uses `.accentColor` for the SF Symbol foreground on top of a `Color.accentColor.opacity(0.12)` background when connected. This creates an accent-on-accent-tint combination that looks visually muddy — low contrast, hard to read, doesn't feel intentional.

**File:** `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/UI/MainChatView+Windows.swift` lines 93-98

```swift
Image(systemName: env.symbol)
    .font(.system(size: 12, weight: .semibold))
    .foregroundColor(envConnected ? .accentColor : .secondary)  // accent on...
    .frame(width: 28, height: 28)
    .background((envConnected ? Color.accentColor : Color.secondary).opacity(0.12))  // ...accent tint
    .clipShape(Circle())
```

## Problem
When connected, the symbol color is `.accentColor` and the circle background is `.accentColor.opacity(0.12)`. The symbol barely reads against its own tinted background. The disconnected state (secondary on secondary tint) has the same issue but is less noticeable.

## Options

**Option A — white symbol, keep accent background**
Make the symbol `.white` when connected and keep the accent-filled circle. Clean, high contrast, matches the send button pattern already used in the app.
```swift
.foregroundColor(envConnected ? .white : .secondary)
.background((envConnected ? Color.accentColor : Color.secondary).opacity(envConnected ? 1.0 : 0.12))
```

**Option B — remove background, keep accent symbol**
Drop the circle background entirely when connected. Symbol sits directly on the header background. Cleaner, less prominent, matches a plain icon style.
```swift
.foregroundColor(envConnected ? .accentColor : .secondary)
// no background
```

**Option C — primary symbol on secondary background**
Use `.primary` for the symbol and `.themeSecondary` for the background regardless of state. Connected state shown differently (e.g. a dot badge or opacity change). Most neutral, fits the title pill aesthetic.

## Recommendation
Option A — most consistent with how the app already handles filled interactive elements (send button, badges). The accent circle reads as "active/connected" clearly without the muddy same-color-on-same-color problem.
