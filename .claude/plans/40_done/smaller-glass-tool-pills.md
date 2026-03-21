# Smaller Glass Tool Pills {rectangle.compress.vertical}
<!-- priority: 10 -->
<!-- tags: tool-pill, ui -->

> Reduced tool pill size by 20% and switched to liquid glass material.

## Summary
Made tool call pills 20% smaller and switched to liquid glass.

## Changes
- `InlineToolPill.swift`: padding 10h/5v → 8h/4v, corner radius 10→8, replaced `.ultraThinMaterial` with `.glassEffect(.regular.interactive())`
- `ToolCallLabel.swift`: icon 12→10pt, text 11→9pt
- `PillStyles.swift`: corner radius 10→8
- Chained command text and children badge also scaled down proportionally
