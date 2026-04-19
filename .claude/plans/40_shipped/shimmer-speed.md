---
title: "Slower Shimmer Animation"
description: "Reduced shimmer animation speed from 1.5s to 2s for a smoother feel."
created_at: 2026-02-12
tags: ["tool-pill", "ui"]
icon: speedometer
build: 71
---


# Slower Shimmer Animation
Reduced tool pill shimmer animation speed from 1.5s to 2s duration for a smoother, less frantic feel.

## Changes
- `ChatView+ToolPill.swift`: Changed `.easeInOut(duration: 1.5)` → `.easeInOut(duration: 2)`
