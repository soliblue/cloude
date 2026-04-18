---
title: "Reduce Header Top Padding"
description: "Removed top padding from window headers to tighten the gap with the iOS navigation bar."
created_at: 2026-03-03
tags: ["ui", "header"]
icon: arrow.up.to.line
build: 82
---


# Reduce Header Top Padding {arrow.up.to.line}
Removed the 7pt top padding from window headers (both regular and heartbeat) to tighten the gap between the iOS navigation bar and the window header. Bottom padding preserved at 7pt.

## Changes
- `MainChatView+Windows.swift`: `.padding(.vertical, 7)` → `.padding(.top, 0)` + `.padding(.bottom, 7)`
- `MainChatView+Heartbeat.swift`: same change
