# Hide Model/Effort from Edit Sheet
<!-- priority: 10 -->
<!-- tags: ui -->
<!-- build: 56 -->

Removed the model selector (cpu icon) and thinking level (brain icon) menus from the window edit sheet toolbar. These controls are redundant since they already exist under the send button and are automatically applied per conversation.

## Changes
- `WindowEditSheet.swift`: Removed effort level Menu and model selector Menu from toolbar
