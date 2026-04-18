# Remove Tool Pill Border {capsule}
<!-- priority: 10 -->
<!-- tags: ui, tool-pill -->
<!-- build: 63 -->

> Removed colored stroke border from tool pills, keeping only shimmer overlay when executing.

## What
Remove the colored stroke border from tool pills — they now render with no border, just the shimmer overlay when executing.

## Changes
- `ChatView+ToolPill.swift`: Removed `.overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(...))` from `pillContent`
