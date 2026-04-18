---
title: "Settings Access Redesign"
description: "Moved settings access to long-press on connection button and tap on Cloude logo, freeing header space."
created_at: 2026-02-17
tags: ["settings", "ui", "header"]
icon: gearshape
build: 71
---


# Settings Access Redesign {gearshape}
## Summary
Move settings access out of the top-left header area. Make it accessible via long-press on the connection status button (top-right) and press on the Cloude logo.

## Motivation
The top-left currently has settings icon(s) taking up space. Scheduled tasks needs a clock button there (next to plans). Clean up by moving settings access to gestures on existing UI elements.

## Design
- **Remove** settings icon(s) from top-left header
- **Long-press connection button** (top-right) → opens settings
- **Tap Cloude logo** → opens settings
- Frees up top-left for: plans button, scheduled tasks button

## Scope
- iOS only — small UI change in header area

## Status
Ready to implement.
