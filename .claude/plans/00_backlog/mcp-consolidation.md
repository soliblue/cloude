---
title: "Consolidate MCP Tools"
description: "Merge widget MCP into the iOS MCP, drop the prefix, and strip unused iOS tools."
created_at: 2026-04-07
tags: ["agent", "streaming"]
icon: wrench.and.screwdriver
build: 145
---


# Consolidate MCP Tools
## Problem

Three issues with the current MCP setup:
- Widget tools live in a separate MCP server when they should be part of the iOS MCP
- iOS MCP tools have a redundant `cloude` prefix (e.g. `mcp__cloude__clipboard`)
- Most iOS MCP tools (notify, haptic, open, delete, rename, skip, switch, symbol) are unused

## Required Work

- Move widget MCP tools (tree, timeline, pie_chart, image_carousel, color_palette, sf_symbols) into the iOS MCP server
- Remove the `cloude` prefix from iOS MCP tool names (keep `mcp__ios__` namespace)
- Keep only `clipboard` and `screenshot` from the iOS MCP; remove the rest
- Remove relay-side MCP forwarding code if no other consumers depend on it
- Update all tool references in skills and CLAUDE.md
