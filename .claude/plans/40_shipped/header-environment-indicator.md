---
title: "Header Environment Indicator"
description: "Added environment icon centered in the window header between tab buttons and action buttons."
created_at: 2026-03-08
tags: ["ui", "header", "env"]
icon: server.rack
build: 82
---

# Header Environment Indicator
## Why
When multi-environment support lands, users need to know which environment they're talking to at a glance. Even before that, it grounds the UI - you're talking to a specific machine.

## Design
- Environment icon sits in the center of the header bar
- Left side: tab switcher buttons (chat, files, git)
- Center: environment icon (SF Symbol representing the machine - e.g., `desktopcomputer`, `server.rack`, `cloud`)
- Right side: action buttons (refresh, close, etc.)
- Tapping the icon could later open an environment switcher (ties into multi-agent-support)

## Implementation
- Add environment icon to `windowHeader` in `MainChatView.swift`
- Use Spacer or frame alignment to center it between the two button groups
- Initially hardcoded to one icon, later driven by `ServerEnvironment` model

## Dependencies
- None for the static version
- Multi-agent-support for dynamic switching
