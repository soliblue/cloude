---
title: "Remove On-Clouds Characters"
description: "Removed three \"on clouds\" pixel art characters from the empty chat state."
created_at: 2026-03-03
tags: ["ui"]
icon: cloud.slash
build: 82
---


# Remove On-Clouds Characters {cloud.slash}
Remove the three "on clouds" pixel art characters from the empty chat state.

## Changes
- `ConversationView+EmptyState.swift`: Removed `artist-claude`, `ninja-claude`, `chef-claude` from characters array
- Deleted 3 on-clouds imagesets from `Assets.xcassets/Claude on Clouds/`
- Kept 5 normal claudes: painter, builder, scientist, boxer, explorer
