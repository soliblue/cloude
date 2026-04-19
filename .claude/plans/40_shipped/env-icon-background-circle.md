---
title: "Environment Icon Background Circle"
description: "Added subtle circular background behind environment icon in window header."
created_at: 2026-03-10
tags: ["ui", "header", "env"]
icon: circle.dashed
build: 82
---


# Environment Icon Background Circle
Add a subtle circular background behind the environment icon in the window header for better visual distinction.

## Changes
- `MainChatView+Windows.swift`: Added 28pt circle with `secondary.opacity(0.12)` background behind env symbol, slightly reduced icon size to 12pt semibold
