---
title: "DS Token Cleanup - Tree Widget & Recording Dot"
description: "Simplify tree widget styling, resize the recording dot with design tokens, and delete the unused connection status view."
created_at: 2026-03-27
tags: ["widget", "cleanup"]
icon: tablecells
build: 115
---


# DS Token Cleanup - Tree Widget & Recording Dot
## Changes
- Tree widget: removed connector lines (vertical + horizontal), removed icon frame, removed icon top padding
- Recording overlay dot: changed from DS.Size.xs to DS.Icon.s
- Deleted dead code: ConnectionStatus component

## Test
- Open any tree widget (e.g. folder structure) — nodes should be indented, no connector lines
- Start a voice recording — pulsing dot should appear larger than before (~14pt base)
