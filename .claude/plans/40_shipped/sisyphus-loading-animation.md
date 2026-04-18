---
title: "Sisyphus Loading Animation"
description: "Added a Sisyphus boulder-pushing animation while waiting for the first token from Claude."
created_at: 2026-03-03
tags: ["ui", "streaming"]
icon: figure.walk
build: 82
---


# Sisyphus Loading Animation {figure.walk}
## What
Small loading animation in the chat area while waiting for the first token from Claude. A tiny character pushes a ball up a hill, it rolls back, repeat — Sisyphus myth.

## Where
- New file: `SisyphusLoadingView.swift` in UI/
- Shown in `ChatMessageList` when `agentState == .running` and no output/tools/stats yet
- Disappears when first character arrives

## Design
- Accent color (orange)
- Small, centered in chat area
- Cute but professional
- Looping animation
