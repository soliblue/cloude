# Remove Tool Pill Border
<!-- build: 63 -->

**Status:** testing
**Tags:** ui, chat

## What
Remove the colored stroke border from tool pills — they now render with no border, just the shimmer overlay when executing.

## Changes
- `ChatView+ToolPill.swift`: Removed `.overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(...))` from `pillContent`
