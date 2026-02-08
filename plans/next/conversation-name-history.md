# Conversation Name History {clock.arrow.trianglehead.counterclockwise.rotate.90}
<!-- priority: 2 -->
<!-- tags: ui, search, metadata -->

> Track previous conversation names so renamed conversations are still findable.

## Problem

Conversations get renamed as topics shift. Once renamed, the old name is lost — makes it hard to find conversations you remember by their earlier name.

## Design Decision

Old names are NOT shown in the main UI — they only surface in search results. When a search matches an old name, show it as secondary text under the current name.

## Plan

- Store name history array in conversation metadata (every `cloude rename` appends to history)
- Old names only visible in search results (no UI clutter elsewhere)
- Make old names searchable (feeds into conversation search feature)

## Files
- `Cloude Agent/` — persist name history when processing `cloude rename`
- `CloudeShared/` — add `previousNames: [String]?` to conversation model
