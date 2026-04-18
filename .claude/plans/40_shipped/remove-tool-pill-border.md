---
title: "Remove Tool Pill Border"
description: "Removed colored stroke border from tool pills, keeping only shimmer overlay when executing."
created_at: 2026-02-08
tags: ["ui", "tool-pill"]
icon: capsule
build: 62
---


# Remove Tool Pill Border {capsule}
## What
Remove the colored stroke border from tool pills — they now render with no border, just the shimmer overlay when executing.

## Changes
- `ChatView+ToolPill.swift`: Removed `.overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(...))` from `pillContent`
