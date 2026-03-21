# Slower Shimmer Animation {speedometer}
<!-- priority: 10 -->
<!-- tags: tool-pill, ui -->

> Reduced shimmer animation speed from 1.5s to 2s for a smoother feel.

Reduced tool pill shimmer animation speed from 1.5s to 2s duration for a smoother, less frantic feel.

## Changes
- `ChatView+ToolPill.swift`: Changed `.easeInOut(duration: 1.5)` → `.easeInOut(duration: 2)`
