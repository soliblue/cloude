---
title: "Frozen Block Split for Tool Calls"
description: "Enable frozen/tail block split for tool-call streaming responses, eliminating FPS degradation from 60 to 20 on long responses."
created_at: 2026-04-01
tags: ["streaming", "performance"]
icon: gauge.with.dots.needle.bottom.50percent
build: 122
---


# Frozen Block Split for Tool Calls
## Changes

- StreamingMarkdownView: tool-call responses now use frozen/tail split with position-adjusted tool calls instead of putting everything in tail
- StreamingMarkdownView: text-only frozen blocks use incremental append (parse delta only) instead of re-parsing all frozen content
- StreamingMarkdownView: tail block prefix ("tail-") computation moved from body to updateIncremental()
- WindowEditForm: 4 @ObservedObject converted to let (parent WindowEditSheet already observes)

## Verify

Outcome: FPS stays above 50 during long streaming responses with tool calls. Markdown renders with correct left alignment. Tool call blocks display correctly during and after streaming.

Test: send a message that triggers tool calls and long markdown output (e.g. "Read the README and summarize the project structure in markdown"), monitor FPS via debug overlay. Verify FPS stays above 50 throughout. Check that headers, lists, code blocks, and tool call labels all render correctly with left alignment.
