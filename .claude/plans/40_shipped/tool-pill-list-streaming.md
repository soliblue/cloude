---
title: "Tool Pill List Unresponsive During Streaming"
description: "Tapping a tool pill while its row is still loading shows visual feedback but does nothing."
created_at: 2026-03-29
tags: ["ui", "streaming"]
icon: wrench.and.screwdriver
build: 120
---


# Tool Pill List Unresponsive During Streaming
## Problem
When multiple tool calls arrive consecutively with no text between them, they render as a horizontal scrollable row. While any tool in that row is still loading:
- Tapping a pill highlights it but the detail sheet does not open
- The list cannot be scrolled horizontally

Both interactions work correctly once all tools in the row have finished loading.

## Desired Outcome
- Tapping any pill in the row opens its detail sheet immediately, even if other pills in the same row are still loading
- The horizontal list is scrollable at all times regardless of loading state

## How to Test
1. Send a prompt that triggers multiple consecutive tool calls (e.g. ask Claude to read several files)
2. While the tools are still streaming/loading, tap one of the pills in the horizontal row
3. The detail sheet should open
4. Also try scrolling the row horizontally while tools are loading
5. Both should work without waiting for all tools to finish
