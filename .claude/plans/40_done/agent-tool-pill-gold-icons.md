# Agent Tool Pill Gold Icons
<!-- build: 86 -->

Give Agent tool pills distinct geometric SF Symbol icons (diamond, pentagon, hexagon, seal, octagon, shield) with gold color. Each agent gets a deterministic icon based on its input hash, so the same agent always shows the same shape. All agents share the gold color to convey "highest order command" status.

## Changes
- `ToolCallLabel.swift`: Added `Agent` case to `iconName` and `toolCallColor`
- Static array of 6 geometric SF Symbols, picked by hashing input
- Gold (`.yellow`) color for all Agent pills
