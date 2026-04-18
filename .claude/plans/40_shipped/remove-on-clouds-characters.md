# Remove On-Clouds Characters {cloud.slash}
<!-- priority: 10 -->
<!-- tags: ui -->
<!-- build: 82 -->

> Removed three "on clouds" pixel art characters from the empty chat state.

Remove the three "on clouds" pixel art characters from the empty chat state.

## Changes
- `ConversationView+EmptyState.swift`: Removed `artist-claude`, `ninja-claude`, `chef-claude` from characters array
- Deleted 3 on-clouds imagesets from `Assets.xcassets/Claude on Clouds/`
- Kept 5 normal claudes: painter, builder, scientist, boxer, explorer
